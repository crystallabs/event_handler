require "./macros"

module EventHandler
  VERSION = "0.5.0"

  ASYNC = false

  # Basic representation of an event. All events must inherit from `Event`.
  #
  # This abstract class is generally not used directly; see macro `event`.
  abstract class Event
    macro inherited
      macro finished
        alias Handler = Proc(\{{@type}}, Bool)
      end
    end
  end

  class Handler(T)
    getter  handler : T
    getter  handler_hash : UInt64
    getter? once : Bool
    getter? async : Bool
    getter  at : Int32
    def initialize(@handler : T, @once, @async, @at, hash = nil)
      @handler_hash = hash || @handler.hash
    end
    def call(obj, async)
      async = @async if async.nil?
      if async
        spawn do @handler.call obj end
        nil
      else
        @handler.call obj
      end
    end
  end

  # Can be used to emit errors. If no handlers are installed when event is emitted, *exception* is raised.
  event ExceptionEvent, exception : Exception

  # Emitted on every event. Listening on this event allows listening on all emitted events and their arguments.
  event AnyEvent, event_type : Event.class, event : Event

  # Emitted whenever a new handler is installed, including handlers for this event.
  event AddHandlerEvent, event : Event.class, handler : EventHandler::Handler(Proc(Event, Bool))

  # Emitted whenever a handler is removed, including handlers for this event.
  event RemoveHandlerEvent, event : Event.class, handler : EventHandler::Handler(Proc(Event, Bool))
end
