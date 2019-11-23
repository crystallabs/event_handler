require "../src/event_handler"

EventHandler.event ClickedEvent, x : Int32, y : Int32
class DoubleClickedEvent < ClickedEvent; end

class My
  include EventHandler
end
my = My.new

ch = ClickedEvent::Channel.new

my.on ClickedEvent, ch, async: true

#spawn do p ch.receive end

my.emit ClickedEvent, 1,2

sleep 1
