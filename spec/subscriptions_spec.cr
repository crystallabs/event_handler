require "./spec_helper"

EventHandler.event PingEvent

module EventHandler
  class TestBag
    include ::EventHandler
  end

  describe Subscriptions do
    it "tears down a tracked teardown block with the event subscriptions" do
      emitter = TestBag.new
      bag = Subscriptions.new
      pings = 0
      cancels = 0
      bag.on(emitter, PingEvent) { pings += 1; true }
      sub = bag.add { cancels += 1 }
      sub.active?.should be_true
      bag.empty?.should be_false

      emitter.emit PingEvent
      pings.should eq 1
      cancels.should eq 0

      bag.off
      emitter.emit PingEvent
      pings.should eq 1
      cancels.should eq 1
      sub.active?.should be_false
      bag.disposed?.should be_true

      bag.off # idempotent: the block does not run again
      cancels.should eq 1
    end

    it "runs an added teardown once when cancelled alone and then in bulk" do
      bag = Subscriptions.new
      cancels = 0
      sub = bag.add { cancels += 1 }
      sub.off
      cancels.should eq 1
      sub.disposed?.should be_true
      bag.off
      cancels.should eq 1
    end

    it "tracks a subscription made elsewhere" do
      emitter = TestBag.new
      bag = Subscriptions.new
      pings = 0
      sub = emitter.on(PingEvent) { pings += 1; true }
      bag.add(sub).should be sub
      emitter.emit PingEvent
      pings.should eq 1
      bag.off
      emitter.emit PingEvent
      pings.should eq 1
      sub.active?.should be_false
    end
  end
end
