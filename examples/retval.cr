require "../src/event_handler"

EventHandler.event ClickedEvent, x : Int32, y : Int32

class ClickedEvent < EventHandler::Event
  property return_value : Int32 = 0
end

class MyClass
  include ::EventHandler
end

c = MyClass.new

c.on(ClickedEvent) { |e| e.return_value += e.x + e.y }

event = c.emit ClickedEvent, 1, 2
p event.return_value # => 3

c.emit ClickedEvent, event
p event.return_value # => 6

c.emit event
p event.return_value # => 9
