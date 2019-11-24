require "../src/event_handler"

EventHandler.event ClickedEvent, x : Int32, y : Int32

class My
  include EventHandler
end
my = My.new

# Create channel and emit an event manually
ch = Channel(ClickedEvent).new
spawn do p ch.receive end
sleep 0.5
my.once(ClickedEvent) { |e| ch.send e}
my.emit(ClickedEvent, 1,2)

# Create channel and call `on` with channel as argument
ch = ClickedEvent::Channel.new
my.once ClickedEvent, ch, async: true
my.emit(ClickedEvent, 1,2)
p ch.receive
