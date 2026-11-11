module EventHandler
  # Meta event, emitted on every other event.
  # Adding a handler for this event allows listening for all emitted events
  # and their arguments.
  #
  # Not emitted for the `AddHandlerEvent`/`RemoveHandlerEvent` the shard
  # itself raises on `on`/`off` (those are dispatched to their own handlers
  # only; one emitted explicitly with `emit` is an ordinary event and does
  # reach `AnyEvent` handlers), nor for an `AnyEvent` emitted directly.
  event AnyEvent,
    event : ::EventHandler::Event

  # Defines a handler meta-event (`AddHandlerEvent` / `RemoveHandlerEvent`).
  #
  # Both carry the identical payload — the event *type* a handler was added to
  # or removed from, plus the `Wrapper` describing that handler — so the shared
  # signature is declared once here. Each call still gets its own doc comment
  # below, for `crystal doc`.
  private macro handler_meta_event(name)
    event {{ name }},
      event : ::EventHandler::Event.class,
      wrapper : ::EventHandler::Wrapper(Proc(Event, Nil))
  end

  # Meta event, emitted whenever a handler is added for any event, including itself.
  #
  # A `Wrapper` is implicitly created for each handler on every `on()`, and
  # besides the handler itself carries the subscription args (*once?*, *async?*,
  # *at*) — giving listeners on this meta event full insight into the handler.
  handler_meta_event AddHandlerEvent

  # Meta event, emitted whenever a handler is removed from any event, including itself.
  #
  # A `Wrapper` is implicitly created for each handler on every `on()`, and
  # besides the handler itself carries the subscription args (*once?*, *async?*,
  # *at*) — giving listeners on this meta event full insight into the handler.
  handler_meta_event RemoveHandlerEvent
end
