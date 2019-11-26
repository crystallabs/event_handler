require "../src/event_handler"

EventHandler.event ClickedEvent, x : Int32, y : Int32

# Define and instantiate a class:

class MyClass
	include ::EventHandler
end
c = MyClass.new

# Add handlers for ClickedEvent in 3 different ways:

c.on(ClickedEvent) { |e| p "Clicked (handler 1). Coordinates are x=#{e.x} y=#{e.y}"}

handler = ->(e : ClickedEvent) { p "Clicked (handler 2). Coordinates are x=#{e.x} y=#{e.y}"; nil }
c.on ClickedEvent, handler

handler = ClickedEvent::Handler.new { |e| p "Clicked (handler 3). Coordinates are x=#{e.x} y=#{e.y}" }
c.on ClickedEvent, handler

# Option 1, with arguments one after another:
c.emit ClickedEvent, 1, 2

hnd = ->(e : ClickedEvent) do
  nil
end
wrapper = EventHandler::Wrapper.new(handler: handler, once: false, async: false, at: -1)

c.on ClickedEvent, hnd

wrapper = ClickedEvent::Wrapper.new(handler: handler, once: false, async: false, at: -1)

c.on ClickedEvent, hnd

# Listen on 3 built-in/meta events:
c.on(::EventHandler::AddHandlerEvent){|e| p "Handler added for #{e.event}! Settings: once=#{e.handler.once?}, async=#{e.handler.async?}, at=#{e.handler.at}"}
c.on(::EventHandler::RemoveHandlerEvent){|e| p "Handler removed for #{e.event}! Settings: once=#{e.handler.once?}, async=#{e.handler.async?}, at=#{e.handler.at}"}
c.on(::EventHandler::AnyEvent) { |e| p "AnyEvent: #{e.class} was emitted: #{e.inspect}" }

# And also the 4th time with options for *async*, *once*, and *at*.
# *async* specifies whether event handler will be invoked in a `Fiber`.
# *once* specifies whether event handler should only run once and then be removed, emitting `RemoveHandlerEvent` as usual.
# *at* specifies the position in the array of existing handlers to insert the new handler into. Typical values are -1 to insert at the end, and 0 to insert at the beginning.

c.on ClickedEvent, handler, async: true, once: true, at: -1

# Emit the event in 2 different ways:

## Option 2, with event, and arguments packed into the event:
c.emit ClickedEvent, ClickedEvent.new 3, 4

# Remove specific listener or all listeners for an event:
#c.off(ClickedEvent, handler)
#c.remove_all_handlers(ClickedEvent)

c.emit ClickedEvent, ClickedEvent.new 3, 4
