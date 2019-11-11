require "../src/event_handler"

# Define event:
event TestEvent, message : String, status : Bool

# Create a class and instantiate it:
class MyClass
  include EventHandler
  event ClickedEvent, x : Int32, y : Int32
end
my = MyClass.new

# Add handlers for the events:

# Add one handler as a block:
my.on(TestEvent) { |e|
  puts "Activated on #{e.class}. Message is '#{e.message}' and status is #{e.status}"
  true
}

# And one as a proc:
handler = ->(e : MyClass::ClickedEvent) {
  puts "Clicked on position x=#{e.x}, y=#{e.y}"
  true
}
my.on MyClass::ClickedEvent, handler

# Emit events:
my.emit TestEvent, "Hello, World!", true
my.emit MyClass::ClickedEvent, 10, 20

# Remove handlers:
my.remove_all_handlers TestEvent
my.off MyClass::ClickedEvent, handler
