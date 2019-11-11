module EventHandler
  VERSION = "0.5.0"
end

require "./macros"
require "./wrapper"
require "./event"
require "./events"

module EventHandler
  # Asynchronous execution flag. By default, asynchronous execution of handlers is disabled.
  #
  # To enable it, set this value to true:
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
  # Also, when an event is emitted, the emitter can choose to override all
  # previous settings and execute all handlers synchronously or asynchronously.
  class_property? async = false
end
