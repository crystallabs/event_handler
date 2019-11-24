require "./spec_helper"

EventHandler.event ClickedEvent, x : Int32, y : Int32

class DoubleClickedEvent < ClickedEvent; end

module EventHandler

  class TestEvents
    include ::EventHandler
  end

  describe EventHandler do
    it "works" do
      Event.should be_truthy
    end

    it "works for builtin events" do
      count = 0
      c = TestEvents.new
      c.on(AddHandlerEvent){|e| count += 1}
      count.should eq 1

      c.handlers(AddHandlerEvent).size.should eq 1

      h1 = ->(e : AddHandlerEvent) { count += 1; nil}
      c.on AddHandlerEvent, h1
      count.should eq 3

      c.handlers(AddHandlerEvent).size.should eq 2

      h2 = AddHandlerEvent::Handler.new { count += 1}
      c.on AddHandlerEvent, h2
      count.should eq 6

      c.handlers(AddHandlerEvent).size.should eq 3

      c.on(RemoveHandlerEvent){|e| count -= 1}
      count.should eq 9

      c.handlers(RemoveHandlerEvent).size.should eq 1

      c.off(AddHandlerEvent, h1)
      count.should eq 8

      c.handlers(AddHandlerEvent).size.should eq 2

      c.off(AddHandlerEvent, h2)
      count.should eq 7

      c.handlers(AddHandlerEvent).size.should eq 1

      # Already removed, so shouldn't change anything
      c.off(AddHandlerEvent, h2)
      count.should eq 7

      c.remove_all_handlers(AddHandlerEvent)
      c.handlers(AddHandlerEvent).should be_empty
    end

    it "works for custom events" do
      count = 0
      c = TestEvents.new
      c.on(ClickedEvent){|e| count += 1; true}
      count.should eq 0

      c.emit ClickedEvent, 1,1
      count.should eq 1

      c.emit ClickedEvent, 1,1
      c.emit ClickedEvent, ClickedEvent.new 1,1
      count.should eq 3

      c.remove_all_handlers(ClickedEvent)
      c.handlers(ClickedEvent).should be_empty
    end

    it "works with subclasses" do
      count = 0
      c = TestEvents.new
      c.on(ClickedEvent){|e| count += e.x + e.y; true}
      c.on(DoubleClickedEvent){|e| count += e.x + e.y; true}

      c.emit ClickedEvent, 1,1
      c.emit DoubleClickedEvent, 1,1

      count.should eq 4
    end

    it "works with channels" do
      c = TestEvents.new
      ch = ClickedEvent::Channel.new
      c.on ClickedEvent, ch
      spawn do c.emit ClickedEvent, 1, 2 end
      ch.receive.class.should eq ClickedEvent
      c.remove_all_handlers ClickedEvent

      spawn do
        c.wait(ClickedEvent).class.should eq ClickedEvent
      end
      spawn do
        c.wait(ClickedEvent).class.should eq ClickedEvent
      end
      spawn do
        c.wait(ClickedEvent) { |e| e.class.should eq ClickedEvent; true}
      end
      spawn do
        c.wait(ClickedEvent, ->(e : ClickedEvent) { e.class.should eq ClickedEvent; nil})
      end

      sleep 0.5
      c.emit ClickedEvent, 1, 2
      sleep 0.5

      c.remove_all_handlers ClickedEvent
      count = 0

      spawn do
        loop do
          c.emit(ClickedEvent, 1,2)
          Fiber.yield
        end
      end

      sleep 0.5

      10.times do |i|
        c.wait(ClickedEvent) { |e| count += i; true }
      end

      count.should eq 45
    end

    it "emits AnyEvents" do
      count = 0
      c = TestEvents.new

      c.on(ClickedEvent){|e| true}
      c.on(::EventHandler::AnyEvent){|e| count += 1; true}
      c.emit ClickedEvent, 1,1
      count.should eq 1
    end

    # TODO missing test for adding events at non-end of queue.
    # (And tests are missing because front-facing functions to
    # add them elsewhere are also missing.)

  end
end
