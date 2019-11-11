require "../src/event_handler"

event ClickedEvent, x : Int32, y : Int32

class X
  include EventHandler
end
x = X.new

handler = ClickedEvent::Handler.new {
  true
}

wrapper = x.on ClickedEvent, handler

x.off ClickedEvent, wrapper
