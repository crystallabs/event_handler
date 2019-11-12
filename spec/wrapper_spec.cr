require "./spec_helper"

EventHandler.event ClickedEvent, x : Int32, y : Int32

module EventHandler

  class TestWrapper
    include ::EventHandler
  end

  describe EventHandler do
    it "works" do
      c = TestWrapper.new
      count = 0

      handler = ClickedEvent::Handler.new {
        count += 1
        true
      }
      wrapper = c.on ClickedEvent, handler

      c.on ClickedEvent, wrapper

      wrapper = ::EventHandler::Wrapper.new(handler)
      c.on ClickedEvent, wrapper

      wrapper = ::EventHandler::Wrapper(Proc(ClickedEvent,Bool)).new() { |x|
        count += 1
        true
      }
      c.on ClickedEvent, wrapper

      wrapper = ClickedEvent::Wrapper.new() { |x|
        count += 1
        true
      }
      c.on ClickedEvent, wrapper

      c.emit ClickedEvent,1,2

      count.should eq 5
    end

  end
end
