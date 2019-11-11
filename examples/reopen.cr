require "../src/event_handler"


event ClickedEvent, x : Int32, y : Int32
class ClickedEvent < ::EventHandler::Event
  property test : String? = "it works"
end

class X
  include EventHandler
end

x = X.new

x.on(ClickedEvent) { |e|
    p "Clicked, value of test is '#{e.test}'"
    true
  }

x.emit(ClickedEvent,1,2)
