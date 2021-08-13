require "../src/event_handler"

# Create an event-enabled class
class MyClass
  include EventHandler
  event ClickedEvent, x : Int32, y : Int32

  def on_clicked(e : ClickedEvent) : Nil
    p :clicked, self
  end

  def on_clicked2(e : ClickedEvent)
    p :clicked, self
  end
end

my = MyClass.new

my.on MyClass::ClickedEvent, ->my.on_clicked(MyClass::ClickedEvent)
my.on MyClass::ClickedEvent, ->my.on_clicked2(MyClass::ClickedEvent)

my.emit MyClass::ClickedEvent, 1, 2
