require "./spec_helper"

EventHandler.event OnceExternalRemoveEvent, x : Int32

module EventHandler
  class TestOnceExternalRemove
    include ::EventHandler
  end

  describe EventHandler do
    # A once-handler that *fires* during an emit but was already removed by an
    # `off` running from an earlier handler in that same dispatch must trigger
    # exactly ONE `RemoveHandlerEvent`. The removing `off` emits it; the batched
    # once-removal in `_emit` must NOT emit a second one, because it did not
    # actually remove anything (the wrapper was already gone). This matches the
    # original per-handler `off` loop, whose second `off` for an already-gone
    # wrapper emitted nothing, and `remove_all_handlers`' per-actual-removal
    # contract.
    it "emits RemoveHandlerEvent once when a fired once-handler was already removed mid-dispatch" do
      c = TestOnceExternalRemove.new
      removed = 0
      c.on(RemoveHandlerEvent) { |e| removed += 1; nil }

      # The once-handler (registered second, so it is later in the list).
      once_handler = OnceExternalRemoveEvent::Handler.new { |e| e.x; nil }

      # First handler removes the once-handler during dispatch (before the
      # once-handler's own slot is reached for removal bookkeeping).
      c.on(OnceExternalRemoveEvent) { |e| c.off(OnceExternalRemoveEvent, once_handler); nil }
      c.on(OnceExternalRemoveEvent, once_handler, once: true)

      c.handlers(OnceExternalRemoveEvent).size.should eq 2

      # Synchronous emit: handler 1 removes the once-handler (1 RemoveHandlerEvent),
      # the once-handler still fires from the snapshot but is already gone, so the
      # batched once-removal must add no further RemoveHandlerEvent.
      c.emit OnceExternalRemoveEvent, 1

      # Only the non-once handler remains.
      c.handlers(OnceExternalRemoveEvent).size.should eq 1
      # Exactly one RemoveHandlerEvent, not two.
      removed.should eq 1
    end
  end
end
