require "../src/event_handler"

EventHandler.event ClickedEvent, x : Int32, y : Int32

class MyClass
	include ::EventHandler
end
my = MyClass.new

p = ClickedEvent::Handler.new { |e| p "Clicked. Coordinates are x=#{e.x} y=#{e.y}"; true }

wrapper = ::EventHandler::Wrapper.new(once: false, async: false, at: -1, handler: p)

#wrapper2 = ::EventHandler::Wrapper.new(once: false, async: false, at: -1) { |e|
#  p "Clicked. Coordinates are x=#{e.x} y=#{e.y}"
#  true
#}

my.on ClickedEvent, wrapper
#my.on ClickedEvent, wrapper2

my.emit ClickedEvent, 1, 2
