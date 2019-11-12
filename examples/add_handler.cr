require "../src/event_handler"

EventHandler.event ClickedEvent, x : Int32, y : Int32

class MyClass
	include ::EventHandler
end

c = MyClass.new

c.on(::EventHandler::AddHandlerEvent){|e| p "Event details are: ", e; true }
c.on(ClickedEvent) { |e| true }
