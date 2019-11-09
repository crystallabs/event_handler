require "./spec_helper"

event ClickedEvent, x : Int32, y : Int32

require "../src/crysterm_post"

module Crysterm

  class TestEvents
    include ::Crysterm::EventEmitter
  end

  describe Crysterm do
    it "works" do
      Event.should be_truthy
    end

    it "works for builtin events" do
      count = 0
      c = TestEvents.new
      c.on(NewListenerEvent){|e| count += 1; true}
      count.should eq 1

      c.listeners(NewListenerEvent).size.should eq 1

      h1 = ->(e : NewListenerEvent) { count += 1; true}
      c.on NewListenerEvent, h1
      count.should eq 3

      c.listeners(NewListenerEvent).size.should eq 2

      h2 = NewListenerEvent::Handler.new { count += 1; true}
      c.on NewListenerEvent, h2
      count.should eq 6

      c.listeners(NewListenerEvent).size.should eq 3

      c.on(RemoveListenerEvent){|e| count -= 1; true}
      count.should eq 9

      c.listeners(RemoveListenerEvent).size.should eq 1

      c.off(NewListenerEvent, h1)
      count.should eq 8

      c.listeners(NewListenerEvent).size.should eq 2

      c.off(NewListenerEvent, h2)
      count.should eq 7

      c.listeners(NewListenerEvent).size.should eq 1

      # Already removed, so shouldn't change anything
      c.off(NewListenerEvent, h2)
      count.should eq 7

      c.remove_all_listeners(NewListenerEvent)
      c.listeners(NewListenerEvent).should be_empty
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

      c.remove_all_listeners(ClickedEvent)
      c.listeners(ClickedEvent).should be_empty
    end

    it "raises if no handlers for ExceptionEvent" do
      count = 0
      c = TestEvents.new

      c.on(::Crysterm::ExceptionEvent){|e| count += 1; true}
      count.should eq 0

      c.emit(::Crysterm::ExceptionEvent, Exception.new("Big error message"))
      count.should eq 1

      c.remove_all_listeners(::Crysterm::ExceptionEvent)

      expect_raises Exception do
        c.emit(::Crysterm::ExceptionEvent, Exception.new("Big error message"))
      end
    end

    it "emits EventEvents" do
      count = 0
      c = TestEvents.new

      c.on(ClickedEvent){|e| true}
      c.on(::Crysterm::EventEvent){|e| count += 1; true}
      c.emit ClickedEvent, 1,1
      count.should eq 1
    end

    # TODO missing test for adding events at non-end of queue.
    # (And tests are missing because front-facing functions to
    # add them elsewhere are also missing.)

  end
end
