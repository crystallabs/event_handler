require "./spec_helper"

EventHandler.event CloneEvent, n : Int32

module EventHandler
  class TestClone
    include ::EventHandler
  end

  describe Wrapper do
    it "clones to an independently registered wrapper with the same handler" do
      c = TestClone.new
      count = 0
      w = CloneEvent::Wrapper.new(once: true) { count += 1 }
      w2 = w.clone
      w2.should_not be w
      w2.handler.should eq w.handler
      w2.handler_hash.should eq w.handler_hash
      w2.once?.should be_true
      c.on CloneEvent, w
      c.on CloneEvent, w2
      c.emit CloneEvent, 1
      count.should eq 2
      c.handlers(CloneEvent).should be_empty
    end
  end
end
