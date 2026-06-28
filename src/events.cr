module EventHandler
  # These events are defined using `class_record` instead of the `event`
  # macro due to: https://github.com/crystal-lang/crystal/issues/8463

  # Meta event, emitted on every other event.
  # Adding a handler for this event allows listening for all emitted events
  # and their arguments.
  event AnyEvent,
    event : ::EventHandler::Event

  # Defines a handler meta-event (`AddHandlerEvent` / `RemoveHandlerEvent`).
  #
  # Both carry the identical payload — the event *type* a handler was added to
  # or removed from, plus the `Wrapper` describing that handler — so the shared
  # signature is declared once here rather than copied at each definition. Each
  # call still gets its own doc comment (below), which documents the emitted
  # event for `crystal doc`.
  private macro handler_meta_event(name)
    event {{name}},
      event : ::EventHandler::Event.class,
      wrapper : ::EventHandler::Wrapper(Proc(Event, Nil))
  end

  # Meta event, emitted whenever a handler is added for any event, including itself.
  #
  # When `AddHandlerEvent` and `RemoveHandlerEvent` are emitted, they invoke
  # their handlers with the `Wrapper` object. A wrapper object for each
  # handler is implicitly created on every `on()`, and in addition to providing
  # access to the handlers themselves, wrappers also contain the values of
  # arguments used during handler subscription (values of *once?*, *async?*,
  # and *at*). This allows listeners on these meta events full insight into
  # the added handlers and their settings.
  handler_meta_event AddHandlerEvent

  # Meta event, emitted whenever a handler is removed from any event, including itself.
  #
  # When `AddHandlerEvent` and `RemoveHandlerEvent` are emitted, they invoke
  # their handlers with the `Wrapper` object. A wrapper object for each
  # handler is implicitly created on every `on()`, and in addition to providing
  # access to the handlers themselves, wrappers also contain the values of
  # arguments used during handler subscription (values of *once?*, *async?*,
  # and *at*). This allows listeners on these meta events full insight into
  # the added handlers and their settings.
  handler_meta_event RemoveHandlerEvent
end
