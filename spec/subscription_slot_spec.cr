require "./spec_helper"

EventHandler.event PingEvent

module EventHandler
  class TestSlot
    include ::EventHandler
  end

  describe Subscription do
    it "exposes the wrapper and handler hash of a slot armed via #on" do
      emitter = TestSlot.new
      slot = Subscription.new
      slot.wrapper.should be_nil
      expect_raises(ArgumentError) { slot.handler_hash }

      pings = 0
      slot.on(emitter, PingEvent) { pings += 1 }
      w = slot.wrapper.should_not be_nil
      slot.handler_hash.should eq w.handler_hash
      emitter.handlers(PingEvent).first.handler_hash.should eq w.handler_hash

      # Re-arming cancels the previous handler and carries the new wrapper.
      slot.on(emitter, PingEvent) { pings += 10 }
      slot.wrapper.should_not be w
      emitter.handlers(PingEvent).size.should eq 1
      emitter.emit PingEvent
      pings.should eq 10

      # The wrapper also serves the re-register form.
      slot.off
      emitter.has_handlers?(PingEvent).should be_false
      emitter.on PingEvent, slot
      emitter.emit PingEvent
      pings.should eq 20
    end

    it "stays active after the handler auto-fired as a once handler" do
      emitter = TestSlot.new
      sub = emitter.once(PingEvent) { }
      emitter.emit PingEvent
      emitter.has_handlers?(PingEvent).should be_false
      sub.active?.should be_true
      sub.off
      sub.active?.should be_false
    end
  end

  describe Subscriptions do
    it "returns a subscription carrying the wrapper" do
      emitter = TestSlot.new
      bag = Subscriptions.new
      sub = bag.on(emitter, PingEvent) { }
      sub.wrapper.should_not be_nil
      sub.handler_hash.should eq emitter.handlers(PingEvent).first.handler_hash
      bag.off
      sub.active?.should be_false
      emitter.has_handlers?(PingEvent).should be_false
    end
  end
end
