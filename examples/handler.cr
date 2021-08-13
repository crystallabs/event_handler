require "../src/event_handler"

p ::EventHandler.async = true
p ::EventHandler.async?

EventHandler.event ClickedEvent, x : Int32, y : Int32

class MyClass
  include ::EventHandler
end

c = MyClass.new

c.on(ClickedEvent) { |e| p "Clicked (handler 1). Coordinates are x=#{e.x} y=#{e.y}" }

handler = ->(e : ClickedEvent) { p "Clicked (handler 2). Coordinates are x=#{e.x} y=#{e.y}" }
c.on ClickedEvent, handler

handler = ClickedEvent::Handler.new { |e| p "Clicked (handler 3). Coordinates are x=#{e.x} y=#{e.y}" }
c.on ClickedEvent, handler
