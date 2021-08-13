require "../src/event_handler"

EventHandler.event ClickedEvent, x : Int32, y : Int32

class MyClass
  include ::EventHandler
end

c = MyClass.new

c.on(ClickedEvent) { |e| p "Clicked (handler 1). Coordinates are x=#{e.x} y=#{e.y}" }

c.emit ClickedEvent, 1, 2

c.off ClickedEvent, -1

# This won't call handler, since it has been removed.
c.emit ClickedEvent, 1, 2
