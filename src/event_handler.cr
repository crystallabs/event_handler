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
