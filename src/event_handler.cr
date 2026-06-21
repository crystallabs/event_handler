module EventHandler
  VERSION = "1.0.3"

  # Compile-time switch for the "skip emit when nothing is subscribed" fast path.
  #
  # When `true` (default), `emit`/`_emit` return immediately if the event has no
  # registered handlers (neither for its concrete type nor for the catch-all
  # `AnyEvent`), avoiding the per-emit reentrant-mutex lock and the handler-array
  # `dup` that the dispatch path otherwise performs on every single emit. On
  # emit-heavy workloads (e.g. a UI render loop firing many events per frame with
  # no listeners) this removes the bulk of per-frame allocations.
  #
  # The fast path reads `Array#empty?` (an `@size` check) without holding the
  # lock. That is a benign race already inherent to the snapshot design: a
  # handler added concurrently with an emit is never guaranteed to observe that
  # emit. If you need every emit to lock unconditionally, flip this to `false`
  # to restore the original behavior verbatim.
  #
  # This is a compile-time constant (not a runtime flag) so that, when disabled,
  # the guard generates no code at all and `emit` keeps its original shape.
  EMIT_SKIP_WHEN_NO_HANDLERS = true

  # Compile-time switch for copy-on-write handler lists.
  #
  # When `true` (default), the per-type handler array is treated as immutable:
  # `on`/`off`/`remove_all_handlers` build a fresh array (copying once at
  # mutation time) and swap it into place under the lock, rather than mutating
  # the shared array in place. This lets `_emit` take its handler-list snapshot
  # by simply *reading the reference* instead of `dup`ing the whole array on
  # every single emit. Since emits typically vastly outnumber subscription
  # changes, this moves the array copy off the hot path: the per-emit allocation
  # (the array `dup`) disappears, replaced by a copy only when handlers are
  # actually added or removed.
  #
  # Because the captured array is never mutated, `_emit` reads its snapshot
  # **without taking the lock at all** — the read is a single atomic pointer
  # load. The mutex is then needed only to serialize *writers* against one
  # another (their dup→mutate→swap is a read-modify-write that would otherwise
  # lose updates), not to guard the emit read path.
  #
  # Correctness is preserved because no array is ever mutated in place while a
  # concurrent (or reentrant) `_emit` might be iterating it: a writer always
  # publishes a brand-new array, and an in-flight emit keeps iterating the
  # snapshot it captured — exactly the semantics the previous `dup` provided.
  # This relies on pointer-sized reference assignment being atomic (true on all
  # supported targets), the same benign-race assumption the empty-list fast path
  # already makes; on the single-threaded fiber scheduler writers never yield
  # mid-swap, and under multi-threading it holds on strongly-ordered targets.
  #
  # Set to `false` to restore the original in-place mutation + per-emit `dup`
  # behavior verbatim; when disabled the copy-on-write code is not generated.
  EMIT_COPY_ON_WRITE = true

  @_event_handler_mutex = ::Mutex.new(:reentrant)
  private getter _event_handler_mutex

  # Emits *event* of of type *event.class*
  def emit(event : ::EventHandler::Event)
    emit event.class, event
  end
end

require "./macros"
require "./wrapper"
require "./event"
require "./events"

module EventHandler
  # Asynchronous execution flag; default false.
  #
  # This setting affects whether event handlers will be executed synchronously
  # one by one, or asynchronously in Fibers.
  #
  # To enable it, set *async* to true:
  #
  # ```
  # EventHandler.async? # => false
  # EventHandler.async = true
  # ```
  #
  # Note that this setting only affects default value.
  #
  # The value can be overriden
  # using the argument *async* by every handler which subscribes to an event.
  class_property? async : Bool = false

  # Asynchronous execution flag for `#wait`ed events; default false.
  #
  # This setting affects whether implicitly created event handlers which
  # forward events through channels will execute synchronously or asynchronously.
  #
  # To enable it, set *async_send* to true:
  #
  # ```
  # EventHandler.async_send? # => false
  # EventHandler.async_send = true
  # ```
  #
  # Note that this setting only affects default value.
  #
  # The value can be overriden
  # using the argument *async_send* on every `#wait`.
  class_property? async_send : Bool = false

  # `RemoveHandlerEvent` control flag for method `remove_all`; default true.
  #
  # It controls whether all handlers removed as part of executing `#remove_all` will
  # emit a `RemoveHandlerEvent`. By default, this setting is true.
  #
  # Disabling it could make sense at application shutdown when executing
  # installed `RemoveHandlerEvent` handlers is not important.
  #
  # To disable it, set *emit_on_remove_all* to false:
  #
  # ```
  # EventHandler.emit_on_remove_all? # => true
  # EventHandler.emit_on_remove_all = false
  # ```
  class_property? emit_on_remove_all : Bool = true

  # Default insertion index when a handler is to be inserted at the beginning of list; default 0.
  #
  # Changing this value might cause "Index out of bounds" Exceptions if used
  # without additional considerations, and changing it should rarely be needed.
  class_property at_beginning : Int32 = 0

  # Default insertion index when a handler is to be inserted at the end of list; default -1.
  #
  # Changing this value might cause "Index out of bounds" Exceptions if used
  # without additional considerations, and changing it should rarely be needed.
  class_property at_end : Int32 = -1
end
