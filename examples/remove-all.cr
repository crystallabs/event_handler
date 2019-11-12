require "../src/event_handler"

EventHandler.event ClickedEvent, x : Int32, y : Int32

class MyClass
	include ::EventHandler
end
c = MyClass.new

c.on(ClickedEvent) { |e| p "Clicked (handler 1). Coordinates are x=#{e.x} y=#{e.y}"; true }
c.on(ClickedEvent) { |e| p "Clicked (handler 1). Coordinates are x=#{e.x} y=#{e.y}"; true }

c.on(EventHandler::RemoveHandlerEvent) { |e| p "Removing a handler"; true }

c.remove_all_handlers ClickedEvent

c.on(ClickedEvent) { |e| p "Clicked (handler 1). Coordinates are x=#{e.x} y=#{e.y}"; true }
c.on(ClickedEvent) { |e| p "Clicked (handler 1). Coordinates are x=#{e.x} y=#{e.y}"; true }

EventHandler.emit_on_remove_all = false

c.remove_all_handlers ClickedEvent
