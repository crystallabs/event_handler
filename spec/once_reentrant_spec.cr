require "./spec_helper"

EventHandler.event ReentrantOnceEvent, n : Int32

module EventHandler
  class TestReentrantOnce
    include ::EventHandler
  end

  describe EventHandler do
    # Fired once-handlers are removed in one batch after the dispatch loop, so
    # while the remaining handlers run, a fired once-handler is still in the
    # published list — and in the snapshot of any nested dispatch. A handler
    # that re-emits the same event must not make the once-handler fire again:
    # `_emit` claims each once-handler before running it, so the nested
    # dispatch skips it.
    it "runs a once-handler exactly once when a later handler re-emits the event" do
      c = TestReentrantOnce.new
      seen = [] of Int32
      c.once(ReentrantOnceEvent) { |e| seen << e.n }
      depth = 0
      c.on(ReentrantOnceEvent) do |e|
        if depth == 0
          depth += 1
          c.emit ReentrantOnceEvent, e.n + 1
        end
      end

      c.emit ReentrantOnceEvent, 1

      seen.should eq [1]
      c.handlers(ReentrantOnceEvent).size.should eq 1
    end

    # Same, with the once-handler *after* the re-emitting handler: the nested
    # dispatch reaches it first and claims it; the outer loop then skips it.
    it "runs a once-handler exactly once when an earlier handler re-emits the event" do
      c = TestReentrantOnce.new
      seen = [] of Int32
      depth = 0
      c.on(ReentrantOnceEvent) do |e|
        if depth == 0
          depth += 1
          c.emit ReentrantOnceEvent, e.n + 1
        end
      end
      c.once(ReentrantOnceEvent) { |e| seen << e.n }

      c.emit ReentrantOnceEvent, 1

      seen.should eq [2]
      c.handlers(ReentrantOnceEvent).size.should eq 1
    end

    # The once-handler's removal is announced exactly once, by the dispatch
    # that actually removed it, not by the nested one that skipped it.
    it "announces the once-handler's removal exactly once under re-emit" do
      c = TestReentrantOnce.new
      removed = 0
      c.on(RemoveHandlerEvent) { |_e| removed += 1 }
      c.once(ReentrantOnceEvent) { |_e| }
      depth = 0
      c.on(ReentrantOnceEvent) do |e|
        if depth == 0
          depth += 1
          c.emit ReentrantOnceEvent, e.n + 1
        end
      end

      c.emit ReentrantOnceEvent, 1

      removed.should eq 1
    end

    # `wait` installs a once-handler doing an unbuffered `Channel#send`. Run
    # twice, the second `send` has no receiver and blocks the emitter forever.
    it "does not deadlock the emitter when wait's event is re-emitted during dispatch" do
      c = TestReentrantOnce.new
      depth = 0
      c.on(ReentrantOnceEvent) do |e|
        if depth == 0
          depth += 1
          c.emit ReentrantOnceEvent, e.n + 1
        end
      end

      # Buffered so neither fiber can block on reporting back.
      done = ::Channel(Symbol).new(2)
      waited = nil
      spawn do
        waited = c.wait(ReentrantOnceEvent).n
        done.send :waited
      end
      spawn do
        c.emit ReentrantOnceEvent, 1
        done.send :emitted
      end

      finished = [] of Symbol
      2.times do
        select
        when s = done.receive
          finished << s
        when timeout(2.seconds)
          raise "deadlock: only #{finished} finished"
        end
      end
      finished.sort.should eq [:emitted, :waited]
      waited.should_not be_nil
      c.handlers(ReentrantOnceEvent).size.should eq 1
    end

    # A once-handler is removed before it runs, so one that raises is gone
    # and does not fire again on the next emit.
    it "removes a raising once-handler" do
      c = TestReentrantOnce.new
      calls = 0
      c.once(ReentrantOnceEvent) { |_e| calls += 1; raise "boom" }

      expect_raises(Exception, "boom") { c.emit ReentrantOnceEvent, 1 }
      c.handlers(ReentrantOnceEvent).should be_empty
      c.emit ReentrantOnceEvent, 2
      calls.should eq 1
    end

    # Since removal precedes the call, a once-handler may re-register itself
    # from inside its own body and stay registered for the next emit.
    it "lets a once-handler re-register itself from its own body" do
      c = TestReentrantOnce.new
      seen = [] of Int32
      sub = nil
      sub = c.once(ReentrantOnceEvent) do |e|
        seen << e.n
        sub.try { |self_sub| c.on ReentrantOnceEvent, self_sub } if e.n == 1
      end

      c.emit ReentrantOnceEvent, 1
      c.handlers(ReentrantOnceEvent).size.should eq 1
      c.emit ReentrantOnceEvent, 2
      c.emit ReentrantOnceEvent, 3
      seen.should eq [1, 2]
      c.handlers(ReentrantOnceEvent).should be_empty
    end

    # A consumed once-wrapper re-registered through its Subscription fires
    # again.
    it "fires a once-wrapper that is re-registered after firing" do
      c = TestReentrantOnce.new
      calls = 0
      sub = c.once(ReentrantOnceEvent) { |_e| calls += 1 }

      c.emit ReentrantOnceEvent, 1
      calls.should eq 1
      c.handlers(ReentrantOnceEvent).should be_empty

      c.on ReentrantOnceEvent, sub
      c.emit ReentrantOnceEvent, 2
      calls.should eq 2
      c.handlers(ReentrantOnceEvent).should be_empty
    end
  end
end
