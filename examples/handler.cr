require "../src/event_handler"
event ClickedEvent, x : Int32, y : Int32
require "../src/finalize"

class MyClass
	include ::EventHandler
end
c = MyClass.new

c.on(ClickedEvent) { |e| p "Clicked (handler 1). Coordinates are x=#{e.x} y=#{e.y}"; true }

handler = ->(e : ClickedEvent) { p "Clicked (handler 2). Coordinates are x=#{e.x} y=#{e.y}"; true }
c.on ClickedEvent, handler

handler = ClickedEvent::Handler.new { |e| p "Clicked (handler 3). Coordinates are x=#{e.x} y=#{e.y}"; true }
c.on ClickedEvent, handler
