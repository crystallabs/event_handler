module EventHandler
  VERSION = "1.0.3"

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
