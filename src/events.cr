module EventHandler
  # These events are defined using `class_record` instead of the `event`
  # macro due to: https://github.com/crystal-lang/crystal/issues/8463

  # Meta event, emitted on every other event.
  # Adding a handler for this event allows listening for all emitted events
  # and their arguments.
  class_record AnyEvent < Event,
    event_type : ::EventHandler::Event.class,
    event : ::EventHandler::Event

  # Meta event, emitted whenever a handler is added for any event, including itself.
  #
  # When `AddHandlerEvent` and `RemoveHandlerEvent` are emitted, they invoke
  # their handlers with the `Wrapper` object. A wrapper object for each
  # handler is implicitly created on every `on()`, and in addition to providing
  # access to the handlers themselves, wrappers also contain the values of
  # arguments used during handler subscription (values of *once?*, *async?*,
  # and *at*). This allows listeners on these meta events full insight into
  # the added handlers and their settings.
  class_record AddHandlerEvent < Event,
    event : ::EventHandler::Event.class,
    handler : ::EventHandler::Wrapper(Proc(Event, Nil))

  # Meta event, emitted whenever a handler is removed from any event, including itself.
  #
  # When `AddHandlerEvent` and `RemoveHandlerEvent` are emitted, they invoke
  # their handlers with the `Wrapper` object. A wrapper object for each
  # handler is implicitly created on every `on()`, and in addition to providing
  # access to the handlers themselves, wrappers also contain the values of
  # arguments used during handler subscription (values of *once?*, *async?*,
  # and *at*). This allows listeners on these meta events full insight into
  # the added handlers and their settings.
  class_record RemoveHandlerEvent < Event,
    event : ::EventHandler::Event.class,
    handler : ::EventHandler::Wrapper(Proc(Event, Nil))
end
