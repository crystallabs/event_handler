require "../src/event_handler"

EventHandler.event ClickedEvent, x : Int32, y : Int32

class MyClass
	include ::EventHandler
end
c = MyClass.new

c.on(ClickedEvent) { |e| p "Clicked (handler 1). Coordinates are x=#{e.x} y=#{e.y}" }
c.on(ClickedEvent) { |e| p "Clicked (handler 1). Coordinates are x=#{e.x} y=#{e.y}" }

c.on(EventHandler::RemoveHandlerEvent) { |e| p "Removing a handler" }

c.remove_all_handlers ClickedEvent

c.on(ClickedEvent) { |e| p "Clicked (handler 1). Coordinates are x=#{e.x} y=#{e.y}" }
c.on(ClickedEvent) { |e| p "Clicked (handler 1). Coordinates are x=#{e.x} y=#{e.y}" }

EventHandler.emit_on_remove_all = false

c.remove_all_handlers ClickedEvent
