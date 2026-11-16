require "./spec_helper"

EventHandler.event IsolatedProbe, value : Int32

module EventHandler
  class TestEmitIsolated
    include ::EventHandler
  end

  describe "emit_isolated" do
    it "returns nil with no handlers and when none raises" do
      c = TestEmitIsolated.new
      c.emit_isolated(IsolatedProbe, 1).should be_nil
      seen = 0
      c.on(IsolatedProbe) { |e| seen += e.value }
      c.emit_isolated(IsolatedProbe, 2).should be_nil
      seen.should eq 2
    end

    it "runs the handlers after a raising one and returns the errors in order" do
      c = TestEmitIsolated.new
      order = [] of Int32
      c.on(IsolatedProbe) { order << 1; raise "first" }
      c.on(IsolatedProbe) { order << 2 }
      c.on(IsolatedProbe) { order << 3; raise "third" }
      c.on(IsolatedProbe) { order << 4 }
      errors = c.emit_isolated(IsolatedProbe, IsolatedProbe.new(0))
      order.should eq [1, 2, 3, 4]
      errors.try(&.map(&.message)).should eq ["first", "third"]
    end

    it "removes a raising once-handler and reaches AnyEvent listeners" do
      c = TestEmitIsolated.new
      any = 0
      later = 0
      c.on(::EventHandler::AnyEvent) { any += 1; raise "any" }
      c.once(IsolatedProbe) { raise "once" }
      c.on(IsolatedProbe) { later += 1 }
      c.emit_isolated(IsolatedProbe, 0).try(&.map(&.message)).should eq ["any", "once"]
      c.emit_isolated(IsolatedProbe, 0).try(&.map(&.message)).should eq ["any"]
      any.should eq 2
      later.should eq 2
    end

    it "leaves emit raising at the first failing handler" do
      c = TestEmitIsolated.new
      reached = false
      c.on(IsolatedProbe) { raise "boom" }
      c.on(IsolatedProbe) { reached = true }
      expect_raises(Exception, "boom") { c.emit IsolatedProbe, 0 }
      reached.should be_false
    end
  end
end
