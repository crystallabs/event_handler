module EventHandler
  VERSION = "2.6.0"

  # Compile-time switch for the "skip emit when nothing is subscribed" fast path.
  #
  # When `true` (default), `emit` returns immediately if the event has no
  # registered handlers (neither its concrete type nor the catch-all
  # `AnyEvent`), and the low-level `_emit` if its own type has none: the
  # handler store is not consulted, (without copy-on-write) the reentrant
  # mutex is not taken, and `emit(type, *args)` does not build the event
  # object. Matters for emit-heavy workloads (e.g. a UI render loop) with no
  # listeners.
  #
  # The fast path tests the emitter's subscription bitmask without holding the
  # lock — a benign race already inherent to the snapshot design (a handler
  # added concurrently with an emit isn't guaranteed to observe that emit). Set
  # to `false` to restore unconditional dispatch; a compile-time constant so
  # the guard generates no code at all when disabled.
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
  # without taking the lock. The mutex only serializes writers against each
  # other (their dup→mutate→swap is a read-modify-write that would otherwise
  # lose updates).
  #
  # Correctness holds because nothing published is mutated in place while a
  # concurrent (or reentrant) `_emit` might be iterating it: a writer always
  # publishes a new array, and an in-flight emit keeps iterating its captured
  # snapshot — the same semantics the previous `dup` provided. Fibers run in
  # parallel on several threads by default, so the publication is an atomic
  # release store read back with an acquire load: an emit on another thread
  # sees either the previous list or the complete new one.
  #
  # Set to `false` to restore the original in-place mutation + per-emit `dup`;
  # when disabled the copy-on-write code is not generated.
  EMIT_COPY_ON_WRITE = true

  # :nodoc:
  #
  # Element type of the per-emitter handler store. An emitter keeps one
  # `Hash(Int32, ErasedHandlers)` (created on its first `on`), keyed by each
  # event type's compile-time index; the value is that type's
  # `Array(Wrapper(Proc(Type, Nil)))`, stored under this common spelling. The
  # cast is a no-op: every such array has the identical layout (a buffer of
  # references), and the shard already hands `Wrapper`s to
  # `AddHandlerEvent`/`RemoveHandlerEvent` listeners under the same erasure.
  # A typed view back is only ever taken by the methods generated for that
  # exact type.
  alias ErasedHandlers = ::Array(::EventHandler::Wrapper(::Proc(::EventHandler::Event, ::Nil)))

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
require "./subscription"

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

  # `RemoveHandlerEvent` control flag for `remove_all_handlers(type)` and its
  # `off(type)` alias; default true.
  #
  # Controls whether handlers removed by those calls emit a
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
  # Rarely needs changing. An index is clamped to the handler list's bounds
  # at insertion (see the *at* option).
  class_property at_beginning : Int32 = 0

  # Default insertion index for a handler inserted at the end of the list; default -1.
  #
  # Rarely needs changing. An index is clamped to the handler list's bounds
  # at insertion (see the *at* option).
  class_property at_end : Int32 = -1
end
