require "../src/event_handler"

class MyClass
  include ::EventHandler
  event ClickedEvent, x : Int32, y : Int32
end

c = MyClass.new

c.on(MyClass::ClickedEvent) { |e| p "Clicked (handler 1). Coordinates are x=#{e.x} y=#{e.y}" }

c.emit MyClass::ClickedEvent, 1, 2
