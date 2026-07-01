module EventHandler
  VERSION = "1.0.3"

  # Compile-time switch for the "skip emit when nothing is subscribed" fast path.
  #
  # When `true` (default), `emit`/`_emit` return immediately if the event has no
  # registered handlers (neither its concrete type nor the catch-all `AnyEvent`),
  # avoiding the per-emit reentrant-mutex lock and handler-array `dup`. Matters
  # for emit-heavy workloads (e.g. a UI render loop) with no listeners.
  #
  # The fast path reads `Array#empty?` without holding the lock — a benign race
  # already inherent to the snapshot design (a handler added concurrently with
  # an emit isn't guaranteed to observe that emit). Set to `false` to restore
  # unconditional locking; a compile-time constant so the guard generates no
  # code at all when disabled.
  EMIT_SKIP_WHEN_NO_HANDLERS = true

  # Compile-time switch for copy-on-write handler lists.
  #
  # When `true` (default), the per-type handler array is immutable: `on`/`off`/
  # `remove_all_handlers` build a fresh array and swap it in under the lock,
  # rather than mutating the shared array in place. This lets `_emit` take its
  # snapshot by reading the reference instead of `dup`ing on every emit — since
  # emits vastly outnumber subscription changes, this moves the copy off the
  # hot path.
  #
  # Because the captured array is never mutated, `_emit` reads its snapshot
  # without taking the lock — a single atomic pointer load. The mutex only
  # serializes writers against each other (their dup→mutate→swap is a
  # read-modify-write that would otherwise lose updates).
  #
  # Correctness holds because no array is mutated in place while a concurrent
  # (or reentrant) `_emit` might be iterating it: a writer always publishes a
  # new array, and an in-flight emit keeps iterating its captured snapshot —
  # the same semantics the previous `dup` provided. Relies on pointer-sized
  # reference assignment being atomic (true on all supported targets).
  #
  # Set to `false` to restore the original in-place mutation + per-emit `dup`;
  # when disabled the copy-on-write code is not generated.
  EMIT_COPY_ON_WRITE = true

  @_event_handler_mutex = ::Mutex.new(:reentrant)
  private getter _event_handler_mutex

  # Emits *event* of type *event.class*
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
  # Controls whether event handlers execute synchronously one by one, or
  # asynchronously in Fibers.
  #
  # ```
  # EventHandler.async? # => false
  # EventHandler.async = true
  # ```
  #
  # Only affects the default; can be overriden per-handler via the *async*
  # argument when subscribing.
  class_property? async : Bool = false

  # Asynchronous execution flag for `#wait`ed events; default false.
  #
  # Controls whether implicitly created handlers that forward events through
  # channels execute synchronously or asynchronously.
  #
  # ```
  # EventHandler.async_send? # => false
  # EventHandler.async_send = true
  # ```
  #
  # Only affects the default; can be overriden per-`#wait` via *async_send*.
  class_property? async_send : Bool = false

  # `RemoveHandlerEvent` control flag for `#remove_all`; default true.
  #
  # Controls whether handlers removed by `#remove_all` emit a
  # `RemoveHandlerEvent`. Disabling can make sense at application shutdown when
  # running those handlers no longer matters.
  #
  # ```
  # EventHandler.emit_on_remove_all? # => true
  # EventHandler.emit_on_remove_all = false
  # ```
  class_property? emit_on_remove_all : Bool = true

  # Default insertion index for a handler inserted at the beginning of the list; default 0.
  #
  # Changing this can cause "Index out of bounds" exceptions if not done carefully;
  # rarely needs changing.
  class_property at_beginning : Int32 = 0

  # Default insertion index for a handler inserted at the end of the list; default -1.
  #
  # Changing this can cause "Index out of bounds" exceptions if not done carefully;
  # rarely needs changing.
  class_property at_end : Int32 = -1
end
