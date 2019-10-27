require "./spec_helper"

class_record ClickedEvent < ::Crysterm::Event, x : Int32, y : Int32

require "../src/event_emitter"

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

      c.removeAllListeners(NewListenerEvent)
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
      c.emit ClickedEvent, 1,1
      count.should eq 3

      c.removeAllListeners(ClickedEvent)
      c.listeners(ClickedEvent).should be_empty
    end

    it "raises if no handlers for ErrorEvent" do
      count = 0
      c = TestEvents.new

      c.on(::Crysterm::ErrorEvent){|e| count += 1; true}
      count.should eq 0

      c.emit(::Crysterm::ErrorEvent, "Big error message")
      count.should eq 1

      c.removeAllListeners(::Crysterm::ErrorEvent)

      expect_raises Exception do
        c.emit(::Crysterm::ErrorEvent, "Big error message")
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

  end
end
