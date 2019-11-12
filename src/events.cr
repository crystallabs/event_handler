module EventHandler
  # Event used for emitting exceptions.
  # If an exception is emitted using this event and there are no handlers subscribed to it, the exception will instead be raised.
  # 
  # Usefulness of this event in the system core is still being evaluated.
  class_record ExceptionEvent < Event, exception : ::Exception

  # Meta event, emitted on every other event.
  # Adding a handler for this event allows listening for all emitted events and their arguments.
  class_record AnyEvent < Event, event_type : ::EventHandler::Event.class, event : ::EventHandler::Event

  # Meta event, emitted whenever a handler is added for any event, including itself.
  class_record AddHandlerEvent < Event, event : ::EventHandler::Event.class, handler : ::EventHandler::Wrapper(Proc(Event, Bool))

  # Meta event, emitted whenever a handler is removed from any event, including itself.
  class_record RemoveHandlerEvent < Event, event : ::EventHandler::Event.class, handler : ::EventHandler::Wrapper(Proc(Event, Bool))
end
