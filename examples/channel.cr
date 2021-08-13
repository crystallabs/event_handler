require "../src/event_handler"

EventHandler.event ClickedEvent, x : Int32, y : Int32

class DoubleClickedEvent < ClickedEvent; end

class My
  include EventHandler
end

my = My.new

ch = ClickedEvent::Channel.new

my.on(ClickedEvent) { |e| ch.send e }
my.once(ClickedEvent) { |e| ch.send e }

spawn do
  3.times do
    p ch.receive
  end
end

my.emit(ClickedEvent, 1, 2)
my.emit(ClickedEvent, 1, 2)

sleep 1
