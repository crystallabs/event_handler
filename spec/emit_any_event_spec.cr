require "./spec_helper"

EventHandler.event AnyDispatchEvent, x : Int32

module EventHandler
  class TestAnyDispatch
    include ::EventHandler
  end

  describe EventHandler do
    # Regression: emitting an `AnyEvent` directly (e.g. via the module-level
    # `emit(event)` helper when the event in hand already is an `AnyEvent`) must
    # fire each `AnyEvent` handler exactly once. Previously `emit(AnyEvent, ...)`
    # dispatched to the `AnyEvent` handler list twice — once through the implicit
    # `_emit AnyEvent, ...` meta-dispatch (which also re-wrapped the event in a
    # second `AnyEvent`) and once through the concrete `_emit(AnyEvent, event)` —
    # so every handler ran twice and saw an `AnyEvent` nested in an `AnyEvent`.
    it "fires AnyEvent handlers once when an AnyEvent is emitted directly" do
      c = TestAnyDispatch.new
      count = 0
      received = nil
      c.on(AnyEvent) { |e| count += 1; received = e; nil }

      inner = AnyDispatchEvent.new(7)
      c.emit AnyEvent.new(inner)

      count.should eq 1
      # The handler must receive the emitted AnyEvent itself, carrying the
      # original event — not an AnyEvent wrapping another AnyEvent.
      received.should be_a AnyEvent
      received.as(AnyEvent).event.should be inner
    end

    it "still fires AnyEvent once for a normal concrete emit" do
      c = TestAnyDispatch.new
      count = 0
      c.on(AnyEvent) { |e| count += 1; nil }
      c.emit AnyDispatchEvent, 3
      count.should eq 1
    end
  end
end
