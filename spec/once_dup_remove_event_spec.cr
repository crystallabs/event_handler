require "./spec_helper"

EventHandler.event OnceDupEvent, x : Int32

module EventHandler
  class TestOnceDup
    include ::EventHandler
  end

  describe EventHandler do
    # A once-handler wrapper that occupies several slots in the list (the same
    # `Wrapper` object added more than once) must, when it fires, be removed once
    # and announced with exactly ONE `RemoveHandlerEvent` — matching both the
    # `remove_all_handlers` "once per distinct wrapper" contract and the original
    # per-handler `off` loop. The batched once-removal in `_emit` collected one
    # entry per slot and emitted a `RemoveHandlerEvent` for each, over-firing for
    # duplicates; it now de-duplicates before announcing.
    it "emits one RemoveHandlerEvent for a once-wrapper registered in multiple slots" do
      c = TestOnceDup.new
      removed = 0
      c.on(RemoveHandlerEvent) { |e| removed += 1; nil }

      # One once-wrapper, registered twice -> two list slots, same object.
      w = c.on(OnceDupEvent, once: true) { |e| e.x; nil }
      c.on(OnceDupEvent, w)
      c.handlers(OnceDupEvent).size.should eq 2

      # Synchronous emit (no fibers/channels): fires the once-handler in both
      # slots, removing the wrapper entirely.
      c.emit OnceDupEvent, 1

      # The wrapper is fully gone...
      c.handlers(OnceDupEvent).size.should eq 0
      # ...and exactly one RemoveHandlerEvent was emitted for that one distinct
      # wrapper (not one per slot).
      removed.should eq 1
    end
  end
end
