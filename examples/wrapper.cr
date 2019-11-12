require "../src/event_handler"

EventHandler.event ClickedEvent, x : Int32, y : Int32

class X
  include EventHandler
end
x = X.new

handler = ClickedEvent::Handler.new {
  true
}

wrapper = x.on ClickedEvent, handler

p x.handlers ClickedEvent

x.off ClickedEvent, wrapper

wrapper = ::EventHandler::Wrapper.new(handler)

p handler.class

wrapper = ::EventHandler::Wrapper(Proc(EventHandler::Event,Bool)).new() { |x|
  true
}

wrapper2 = ClickedEvent::Wrapper.new() { |x|
  true
}

#x.on ClickedEvent, wrapper
