require "./spec_helper"

EventHandler.event ClickedEvent, x : Int32, y : Int32

module EventHandler

  class TestRemove
    include ::EventHandler
  end

  describe EventHandler do
    it "works" do
      c = TestRemove.new
      count = 0

      c.on(ClickedEvent) { |e| p "Clicked (handler 1). Coordinates are x=#{e.x} y=#{e.y}"; true }
      c.on(ClickedEvent) { |e| p "Clicked (handler 1). Coordinates are x=#{e.x} y=#{e.y}"; true }
      c.on(ClickedEvent) { |e| p "Clicked (handler 1). Coordinates are x=#{e.x} y=#{e.y}"; true }
      c.on(ClickedEvent) { |e| p "Clicked (handler 1). Coordinates are x=#{e.x} y=#{e.y}"; true }

      c.on(EventHandler::RemoveHandlerEvent) { |e| count += 1; true }

      c.remove_all_handlers ClickedEvent

      c.handlers(ClickedEvent).size.should eq 0
      count.should eq 4

      handler = ClickedEvent::Handler.new() { |e| e.x; e.y; true }

      w1 = c.on(ClickedEvent, handler)
      w2 = c.on(ClickedEvent, handler)
      c.on(ClickedEvent, w2)
      c.on(ClickedEvent, w2)
      c.on(ClickedEvent, w2)
      c.on(ClickedEvent, w2)
      w3 = c.on(ClickedEvent, handler)
      w4 = c.on(ClickedEvent, handler)

      c.off(ClickedEvent, w1.handler_hash)

      c.handlers(ClickedEvent).size.should eq 7

      c.off(ClickedEvent, w1.handler_hash)

      c.handlers(ClickedEvent).size.should eq 2

      c.off(ClickedEvent, handler)

      c.handlers(ClickedEvent).size.should eq 1

      c.off(ClickedEvent, handler)

      c.handlers(ClickedEvent).size.should eq 0

      c.on(ClickedEvent, handler)
      c.on(ClickedEvent, handler)
      c.on(ClickedEvent, handler)

      c.handlers(ClickedEvent).size.should eq 3

      c.off(ClickedEvent)

      c.handlers(ClickedEvent).size.should eq 0
    end
  end
end
