require "./spec_helper"

EventHandler.event OffDedupEvent, x : Int32

module EventHandler
  class TestOffDedup
    include ::EventHandler
  end

  # The predicate-based `off` overloads — `off(handler)`, `off(hash)` and
  # `off(wrapper)` — now share a single removal core (`_off_first`). These specs
  # lock in that each overload still routes through it correctly: it locates the
  # first matching wrapper, removes *every identical copy* of it, returns the
  # removed wrapper (or nil), and never spills into the catch-all `off(emit)`
  # overload that would wipe the whole list.
  describe EventHandler do
    it "off(handler) removes one wrapper per call and returns it" do
      c = TestOffDedup.new
      handler = OffDedupEvent::Handler.new { |e| e.x; nil }
      c.on OffDedupEvent, handler
      c.on OffDedupEvent, handler
      c.handlers(OffDedupEvent).size.should eq 2

      removed = c.off(OffDedupEvent, handler)
      removed.should_not be_nil
      c.handlers(OffDedupEvent).size.should eq 1

      c.off(OffDedupEvent, handler)
      c.handlers(OffDedupEvent).size.should eq 0
      # Already gone: returns nil, removes nothing.
      c.off(OffDedupEvent, handler).should be_nil
    end

    it "off(hash) removes all identical copies of the matched wrapper" do
      c = TestOffDedup.new
      handler = OffDedupEvent::Handler.new { |e| e.x; nil }
      w = c.on OffDedupEvent, handler
      # Re-add the *same* wrapper object several times.
      c.on OffDedupEvent, w
      c.on OffDedupEvent, w
      c.handlers(OffDedupEvent).size.should eq 3

      # One `off(hash)` removes every identical copy of that wrapper at once.
      c.off OffDedupEvent, w.handler_hash
      c.handlers(OffDedupEvent).size.should eq 0
    end

    it "off(wrapper) removes by identity given concrete or erased wrapper" do
      c = TestOffDedup.new
      captured = nil
      c.on(AddHandlerEvent) { |e| captured = e.wrapper; nil }

      # Concrete wrapper returned by `on`.
      w = c.on(OffDedupEvent) { |e| e.x; nil }
      c.handlers(OffDedupEvent).size.should eq 1
      c.off(OffDedupEvent, w).should_not be_nil
      c.handlers(OffDedupEvent).size.should eq 0

      # Erased wrapper handed to AddHandlerEvent handlers.
      c.on(OffDedupEvent) { |e| e.x; nil }
      captured.should_not be_nil
      c.off(OffDedupEvent, captured.not_nil!).should_not be_nil
      c.handlers(OffDedupEvent).size.should eq 0
    end
  end
end
