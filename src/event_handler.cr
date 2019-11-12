module EventHandler
  VERSION = "0.6.0"
end

require "./macros"
require "./wrapper"
require "./event"
require "./events"

module EventHandler
  # Asynchronous execution flag. By default, asynchronous execution of handlers is disabled.
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
  class_property? async = false

  # `RemoveHandlerEvent` control flag for method `#remove_all`.
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
  class_property? emit_on_remove_all = true

  # Default insertion index when a handler is to be inserted at the beginning of list.
  #
  # Changing this value might cause "Index out of bounds" Exceptions if used
  # without additional considerations, and changing it should rarely be needed.
  class_property at_beginning = 0

  # Default insertion index when a handler is to be inserted at the end of list.
  #
  # Changing this value might cause "Index out of bounds" Exceptions if used
  # without additional considerations, and changing it should rarely be needed.
  class_property at_end = -1
end
