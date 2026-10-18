require "../src/event_handler"

EventHandler.event ClickedEvent, x : Int32, y : Int32

class MyClass
  include ::EventHandler
end

c = MyClass.new

p = ClickedEvent::Handler.new { |e| p "Clicked. Coordinates are x=#{e.x} y=#{e.y}" }

c.on(ClickedEvent, p)
c.on(ClickedEvent, p)
c.on(ClickedEvent, p)
c.on(ClickedEvent, p)
subscription = c.on(ClickedEvent, p)
wrapper = subscription.wrapper.not_nil!

c.on ClickedEvent, wrapper
c.on ClickedEvent, wrapper
c.on ClickedEvent, wrapper
c.on ClickedEvent, wrapper
c.on ClickedEvent, wrapper

p c.handlers(ClickedEvent).size # => 10

# Each `off` returns the removed wrapper (or nil); the sizes show what it left.
c.off ClickedEvent, p
p c.handlers(ClickedEvent).size # => 9 (removes first one found)

c.off ClickedEvent, p.hash
p c.handlers(ClickedEvent).size # => 8 (now removes again first one found)

c.off ClickedEvent, wrapper
p c.handlers(ClickedEvent).size # => 2 (removes all last 6 wrappers)

c.emit ClickedEvent, ClickedEvent.new(1, 1)
