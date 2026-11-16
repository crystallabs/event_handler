require "./spec_helper"

EventHandler.event RescuedProbe, value : Int32

module EventHandler
  class TestEmitRescued
    include ::EventHandler
  end

  describe "emit_rescued" do
    it "returns nil with no handlers and when none raises" do
      c = TestEmitRescued.new
      c.emit_rescued(RescuedProbe, 1).should be_nil
      seen = 0
      c.on(RescuedProbe) { |e| seen += e.value }
      c.emit_rescued(RescuedProbe, 2).should be_nil
      seen.should eq 2
    end

    it "runs the handlers after a raising one and returns the errors in order" do
      c = TestEmitRescued.new
      order = [] of Int32
      c.on(RescuedProbe) { order << 1; raise "first" }
      c.on(RescuedProbe) { order << 2 }
      c.on(RescuedProbe) { order << 3; raise "third" }
      c.on(RescuedProbe) { order << 4 }
      errors = c.emit_rescued(RescuedProbe, RescuedProbe.new(0))
      order.should eq [1, 2, 3, 4]
      errors.try(&.map(&.message)).should eq ["first", "third"]
    end

    it "removes a raising once-handler and reaches AnyEvent listeners" do
      c = TestEmitRescued.new
      any = 0
      later = 0
      c.on(::EventHandler::AnyEvent) { any += 1; raise "any" }
      c.once(RescuedProbe) { raise "once" }
      c.on(RescuedProbe) { later += 1 }
      c.emit_rescued(RescuedProbe, 0).try(&.map(&.message)).should eq ["any", "once"]
      c.emit_rescued(RescuedProbe, 0).try(&.map(&.message)).should eq ["any"]
      any.should eq 2
      later.should eq 2
    end

    it "leaves emit raising at the first failing handler" do
      c = TestEmitRescued.new
      reached = false
      c.on(RescuedProbe) { raise "boom" }
      c.on(RescuedProbe) { reached = true }
      expect_raises(Exception, "boom") { c.emit RescuedProbe, 0 }
      reached.should be_false
    end
  end
end
