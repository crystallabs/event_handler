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
x.on ClickedEvent, wrapper


wrapper = ::EventHandler::Wrapper.new(handler)
x.on ClickedEvent, wrapper


wrapper = ClickedEvent::Wrapper.new() { |x|
  true
}
x.on ClickedEvent, wrapper

wrapper = ::EventHandler::Wrapper(Proc(ClickedEvent,Nil)).new() { |x|
  true
}
x.on ClickedEvent, wrapper

p x.handlers(ClickedEvent).size

x.on ::EventHandler::AddHandlerEvent do |e|
  p e
  p e.wrapper.once?
end

x.emit ClickedEvent, 1,2
