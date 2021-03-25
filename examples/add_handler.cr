require "../src/event_handler"

EventHandler.event ClickedEvent, x : Int32, y : Int32

class MyClass
	include ::EventHandler
end

my = MyClass.new

my.on(::EventHandler::AddHandlerEvent){|e| p "Event details are: ", e }
my.on(ClickedEvent) { |e| true }

myhandler = ->(e : ClickedEvent) do
end
wrapper = ::EventHandler::Wrapper.new(handler: myhandler, once: false, async: false, at: -1)

my.on ClickedEvent, wrapper

