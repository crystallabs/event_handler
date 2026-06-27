require "./spec_helper"

EventHandler.event OffAtEvent, x : Int32

module EventHandler
  class TestOffAt
    include ::EventHandler
  end

  describe EventHandler do
    # Regression: `off(type, at:)` must remove ONLY the single handler at the
    # given index. Previously the concrete-typed wrapper read from the list did
    # not match the erased `off(type, wrapper)` overload and fell through to
    # `off(type, emit = ...)`, wiping every handler instead.
    it "off(type, at:) removes only the handler at that index" do
      c = TestOffAt.new

      w0 = c.on(OffAtEvent) { |e| e.x; true }
      w1 = c.on(OffAtEvent) { |e| e.x; true }
      w2 = c.on(OffAtEvent) { |e| e.x; true }

      c.handlers(OffAtEvent).size.should eq 3

      removed = c.off(OffAtEvent, at: 1)

      # Exactly one handler removed (not all of them), and it was the one at idx 1.
      c.handlers(OffAtEvent).size.should eq 2
      removed.should eq w1
      c.handlers(OffAtEvent).should eq [w0, w2]
    end
  end
end
