require "../src/event_handler"

EventHandler.event ClickedEvent, x : Int32, y : Int32

class MyClass
	include ::EventHandler
end
c = MyClass.new

handler = ->(e : ClickedEvent) { p e }
c.on ClickedEvent, handler

handler = Proc(ClickedEvent, Nil).new { |e| p e }
c.on ClickedEvent, handler

handler = ClickedEvent::Handler.new { |e| p e }
c.on ClickedEvent, handler

c.on(ClickedEvent) { |e|
  p e
}

c.emit ClickedEvent, 1,2
