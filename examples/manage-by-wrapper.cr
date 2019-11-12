require "../src/event_handler"

EventHandler.event ClickedEvent, x : Int32, y : Int32

class MyClass
	include ::EventHandler
end
c = MyClass.new

p = ClickedEvent::Handler.new { |e| p "Clicked. Coordinates are x=#{e.x} y=#{e.y}"; true }

c.on(ClickedEvent, p)
c.on(ClickedEvent, p)
c.on(ClickedEvent, p)
c.on(ClickedEvent, p)
wrapper = c.on(ClickedEvent, p)

c.on ClickedEvent, wrapper
c.on ClickedEvent, wrapper
c.on ClickedEvent, wrapper
c.on ClickedEvent, wrapper
c.on ClickedEvent, wrapper

p c.handlers(ClickedEvent).size # => 10

p c.off ClickedEvent, p # => 9 (removes first one found)

p c.off ClickedEvent, p.hash # => 8 (now removes again first one found)

p c.off ClickedEvent, wrapper # => 2 (removes all last 6 wrappers)

p c.handlers(ClickedEvent).size

c.emit ClickedEvent, ClickedEvent.new(1, 1)
