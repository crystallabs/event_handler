require "../src/event_handler"

# Define an event
EventHandler.event TestEvent, message : String, status : Bool

# Create an event-enabled class
class MyClass
  include EventHandler
  event ClickedEvent, x : Int32, y : Int32
end
my = MyClass.new

# Add a block as event handler
my.on(TestEvent) do |e|
  puts "Activated on #{e.class}. Message is '#{e.message}' and status is #{e.status}"
  true
end

# And a Proc as event handler
handler = ->(e : MyClass::ClickedEvent) do
  puts "Clicked on position x=#{e.x}, y=#{e.y}"
  nil
end
my.on MyClass::ClickedEvent, handler

# Emit events
my.emit TestEvent, "Hello, World!", true
my.emit MyClass::ClickedEvent, 10, 20

# Remove handlers
my.remove_all_handlers TestEvent
my.off MyClass::ClickedEvent, handler
