require "../src/event_handler"

EventHandler.event ClickedEvent, x : Int32, y : Int32

class My
  include EventHandler
end
my = My.new

# Create a channel, wait for event, and print it
channel = ClickedEvent::Channel.new
my.once ClickedEvent, channel, async: true
my.emit(ClickedEvent, 1,2)
p channel.receive

# Same as above, implemented manually
channel = Channel(ClickedEvent).new
my.once(ClickedEvent, async: true) { |e| channel.send e }
my.emit(ClickedEvent, 1,2)
p channel.receive

my.remove_all_handlers ClickedEvent

def on_clicked(e : ClickedEvent) : Nil
  p e
end

# Wait for event
spawn do
  e = my.wait(ClickedEvent, async_send: true)
  p e

  my.wait(ClickedEvent, async_send: true) { |e| p e}

  my.wait(ClickedEvent) do |e|
    p e
  end

  handler = ClickedEvent::Handler.new do |e| p e end
  my.wait ClickedEvent, handler

  my.wait(ClickedEvent, ->on_clicked(ClickedEvent))
end

sleep 0.5
my.emit(ClickedEvent, 1,2)

sleep 0.5
my.emit(ClickedEvent, 1,2)

sleep 0.5
my.emit(ClickedEvent, 1,2)

sleep 0.5
my.emit(ClickedEvent, 1,2)

sleep 0.5
my.emit(ClickedEvent, 1,2)

sleep 0.5
