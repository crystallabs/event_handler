require "./spec_helper"

EventHandler.event LazyStoreEventA, x : Int32
EventHandler.event LazyStoreEventB

module EventHandler
  class TestLazyStore
    include ::EventHandler
  end

  # Handler storage is lazy: an emitter holds nothing for an event type until
  # the first `on`, drops it again on the last `off`, and reports presence
  # through `has_handlers?` without allocating. These specs lock in the
  # observable side of that: empty results for never-subscribed types, the
  # presence flag following every add/remove path, and the whole-object
  # `remove_all_handlers` still announcing each removal when asked to.
  describe EventHandler do
    it "reports no handlers, and an empty list, for a never-subscribed type" do
      c = TestLazyStore.new
      c.has_handlers?(LazyStoreEventA).should be_false
      c.handlers(LazyStoreEventA).should be_empty
      # The returned list is a fresh copy: mutating it does not subscribe.
      c.handlers(LazyStoreEventA) << LazyStoreEventA::Wrapper.new { |_e| }
      c.has_handlers?(LazyStoreEventA).should be_false
    end

    it "emits to nothing, without error, on a fresh emitter" do
      c = TestLazyStore.new
      c.emit(LazyStoreEventA, 1).should be_nil
      c.emit(LazyStoreEventB).should be_nil
      c.remove_all_handlers
      c.off(LazyStoreEventA, 0).should be_nil
      c.off(LazyStoreEventA, LazyStoreEventA::Handler.new { |_e| }).should be_nil
    end

    it "tracks presence per type through every add and remove path" do
      c = TestLazyStore.new
      s1 = c.on(LazyStoreEventA) { |_e| }
      s2 = c.on(LazyStoreEventA) { |_e| }
      c.has_handlers?(LazyStoreEventA).should be_true
      c.has_handlers?(LazyStoreEventB).should be_false

      s1.off
      c.has_handlers?(LazyStoreEventA).should be_true
      c.off(LazyStoreEventA, s2.handler_hash)
      c.has_handlers?(LazyStoreEventA).should be_false
      c.handlers(LazyStoreEventA).should be_empty

      c.on(LazyStoreEventA) { |_e| }
      c.off(LazyStoreEventA, 0)
      c.has_handlers?(LazyStoreEventA).should be_false

      c.on(LazyStoreEventA) { |_e| }
      c.remove_all_handlers(LazyStoreEventA)
      c.has_handlers?(LazyStoreEventA).should be_false

      c.once(LazyStoreEventA) { |_e| }
      c.has_handlers?(LazyStoreEventA).should be_true
      c.emit LazyStoreEventA, 1
      c.has_handlers?(LazyStoreEventA).should be_false
    end

    it "keeps other types intact when one type's last handler goes" do
      c = TestLazyStore.new
      hits = [] of Int32
      c.on(LazyStoreEventA) { |e| hits << e.x }
      b = c.on(LazyStoreEventB) { |_e| hits << -1 }
      b.off
      c.emit LazyStoreEventA, 7
      c.emit LazyStoreEventB
      hits.should eq [7]
      c.has_handlers?(LazyStoreEventA).should be_true
      c.has_handlers?(LazyStoreEventB).should be_false
    end

    it "whole-object remove_all_handlers clears every type and, when asked, announces each removal" do
      c = TestLazyStore.new
      removed = [] of ::EventHandler::Event.class
      c.on(RemoveHandlerEvent) { |e| removed << e.event }
      c.on(LazyStoreEventA) { |_e| }
      wb = c.on(LazyStoreEventB) { |_e| }
      c.on(LazyStoreEventB, wb) # the same wrapper twice: announced once

      c.remove_all_handlers emit: true
      c.has_handlers?(LazyStoreEventA).should be_false
      c.has_handlers?(LazyStoreEventB).should be_false
      c.has_handlers?(RemoveHandlerEvent).should be_false
      # Every other type is announced to the listener present at the call;
      # the listener itself goes last, with nothing left to announce it to
      # (as `remove_all_handlers(RemoveHandlerEvent, true)` behaves).
      removed.sort_by(&.name).should eq [LazyStoreEventA, LazyStoreEventB].sort_by(&.name)
    end

    it "whole-object remove_all_handlers announces nothing by default" do
      c = TestLazyStore.new
      removed = 0
      c.on(RemoveHandlerEvent) { |_e| removed += 1 }
      c.on(LazyStoreEventA) { |_e| }
      c.remove_all_handlers
      removed.should eq 0
      c.has_handlers?(LazyStoreEventA).should be_false
    end
  end
end
