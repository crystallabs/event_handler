require "../src/event_handler"

EventHandler.event ClickedEvent, x : Int32, y : Int32

class My
  include EventHandler
end
my = My.new

spawn do
  loop do
    my.emit(ClickedEvent, 1,2)
    sleep 0.2
  end
end

sleep 1

10.times do |i|
  my.wait(ClickedEvent) { |e| print i; true }
end
puts

ch = ClickedEvent::Channel.new
my.once(ClickedEvent, ch)
e = ch.receive
p e
