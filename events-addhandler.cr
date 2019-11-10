require "../src/events"

event ClickedEvent, x : Int32, y : Int32

require "../src/event_emitter"

class MyClass
	include ::Crysterm::EventEmitter
end
c = MyClass.new

c.on(::Crysterm::AddHandlerEvent){|e| p "Event details are: ", e; true }
c.on(ClickedEvent) { |e| true }
