require "./spec_helper"

EventHandler.event RegNamed, name : String
EventHandler.event RegCounted, n : Int32

# Same name as a constant inside `EventHandler`.
EventHandler.event ErasedHandlers, n : Int32

# Underscore to the same identifier.
EventHandler.event RegHTTPDone, n : Int32
EventHandler.event RegHttpDone, s : String

EventHandler.event RegBase, n : Int32

class RegDerived < RegBase
end

EventHandler.event RegWithBlock, n : Int32 do
  def double
    n * 2
  end
end

EventHandler.event RegVeto

class RegEmitter
  include EventHandler
end

describe "EventHandler regressions" do
  it "keeps the event type of a cloned erased wrapper" do
    e = RegEmitter.new
    w = e.on(RegNamed) { }.wrapper.should_not be_nil
    c = w.clone
    c.should_not be(w)
    c.event_type.should eq RegNamed
    c.handler_hash.should eq w.handler_hash
    expect_raises(ArgumentError) { e.on(RegCounted, c) }
    e.handlers(RegCounted).size.should eq 0
  end

  it "supports an event named like one of the shard's constants" do
    e = RegEmitter.new
    got = 0
    sub = e.on(::ErasedHandlers) { |event| got = event.n }
    e.emit ::ErasedHandlers, 5
    got.should eq 5
    w = sub.wrapper.should_not be_nil
    w.event_type.should eq ::ErasedHandlers
    expect_raises(ArgumentError) { e.on(RegCounted, w) }
  end

  it "keeps events whose names underscore identically apart" do
    e = RegEmitter.new
    seen = [] of String
    e.on(RegHTTPDone) { |event| seen << "HTTP #{event.n}" }
    e.on(RegHttpDone) { |event| seen << "Http #{event.s}" }
    e.emit RegHTTPDone, 1
    e.emit RegHttpDone, "x"
    seen.should eq ["HTTP 1", "Http x"]
  end

  it "emits an event held as a plain Event on its actual class" do
    e = RegEmitter.new
    seen = [] of String
    e.on(RegNamed) { |event| seen << event.name }
    e.on(RegCounted) { |event| seen << event.n.to_s }
    e.on(RegDerived) { |event| seen << "derived #{event.n}" }
    events = [RegNamed.new("a"), RegCounted.new(2), RegDerived.new(3)] of EventHandler::Event
    events.each { |event| e.emit event }
    seen.should eq ["a", "2", "derived 3"]
  end

  it "forwards AnyEvent#event to another emitter" do
    a = RegEmitter.new
    b = RegEmitter.new
    got = 0
    b.on(RegCounted) { |event| got = event.n }
    a.on(EventHandler::AnyEvent) { |any| b.emit any.event }
    a.emit RegCounted, 9
    got.should eq 9
  end

  it "accepts the run-time event type a meta event carries" do
    e = RegEmitter.new
    added = [] of {EventHandler::Event.class, EventHandler::Wrapper(Proc(EventHandler::Event, Nil))}
    e.on(EventHandler::AddHandlerEvent) { |event| added << {event.event, event.wrapper} }
    e.on(RegCounted) { }
    type, wrapper = added.last
    e.has_handlers?(type).should be_true
    e.handlers(type).size.should eq 1
    e.handlers(type).first.should be(wrapper)
    e.off(type, wrapper).should be(wrapper)
    e.has_handlers?(type).should be_false
    e.on(type, wrapper)
    e.handlers(RegCounted).size.should eq 1
    expect_raises(ArgumentError) { e.on(RegNamed.as(EventHandler::Event.class), wrapper) }
  end

  it "undoes the registration when an AddHandlerEvent listener raises" do
    e = RegEmitter.new
    removed = 0
    e.on(EventHandler::AddHandlerEvent) { |event| raise "veto" if event.event == RegVeto }
    e.on(EventHandler::RemoveHandlerEvent) { removed += 1 }
    expect_raises(Exception, "veto") { e.on(RegVeto) { } }
    e.handlers(RegVeto).size.should eq 0
    e.has_handlers?(RegVeto).should be_false
    removed.should eq 1
    expect_raises(Exception, "veto") { e.wait(RegVeto) }
    e.handlers(RegVeto).size.should eq 0
    e.emit RegVeto # must return
  end

  it "gives a dup'd emitter its own handler lists" do
    a = RegEmitter.new
    calls = [] of String
    a.on(RegCounted) { calls << "a" }
    b = a.dup
    b.on(RegCounted) { calls << "b" }
    a.handlers(RegCounted).size.should eq 1
    b.handlers(RegCounted).size.should eq 2
    b.off(RegCounted, at: 0)
    a.handlers(RegCounted).size.should eq 1
    a.emit RegCounted, 1
    calls.should eq ["a"]
  end

  it "removes a handler typed for an ancestor event" do
    e = RegEmitter.new
    h = ->(event : RegBase) { nil }
    e.on(RegDerived, h)
    e.off(RegDerived, h).should_not be_nil
    e.handlers(RegDerived).size.should eq 0
  end

  it "fires and removes the base event's once-handlers for emit(Derived, base)" do
    e = RegEmitter.new
    fired = 0
    e.once(RegBase) { fired += 1 }
    e.emit RegDerived, RegBase.new(1)
    fired.should eq 1
    e.handlers(RegBase).size.should eq 0
  end

  it "passes the block of `event` into the class body" do
    RegWithBlock.new(2).double.should eq 4
  end

  it "accepts any integer type for at" do
    e = RegEmitter.new
    order = [] of Int32
    e.on(RegCounted) { order << 1 }
    e.on(RegCounted, at: 0_i64) { order << 0 }
    e.on(RegCounted, at: UInt64::MAX) { order << 2 }
    e.emit RegCounted, 0
    order.should eq [0, 1, 2]
  end

  describe "Subscription#live?" do
    it "tracks the handler's presence" do
      e = RegEmitter.new
      s = e.once(RegCounted) { }
      s.live?.should be_true
      e.emit RegCounted, 1
      s.active?.should be_true
      s.live?.should be_false

      s2 = e.on(RegCounted) { }
      e.remove_all_handlers
      s2.live?.should be_false

      s3 = EventHandler::Subscriptions.new.add { }
      s3.live?.should be_true
      s3.off
      s3.live?.should be_false
    end

    it "follows a slot re-armed with Subscription#on" do
      e = RegEmitter.new
      slot = EventHandler::Subscription.new
      slot.live?.should be_false
      slot.on(e, RegCounted) { }
      slot.live?.should be_true
      e.off RegCounted
      slot.live?.should be_false
    end
  end

  it "drops dead subscriptions from a Subscriptions bag" do
    e = RegEmitter.new
    bag = EventHandler::Subscriptions.new
    1000.times { bag.on(e, RegCounted) { }.off }
    1000.times { bag.on(e, RegCounted, once: true) { } }
    e.emit RegCounted, 1
    keep = bag.on(e, RegCounted) { }
    100.times { bag.on(e, RegCounted) { }.off }
    bag.@subs.size.should be < 64
    bag.@subs.includes?(keep).should be_true
    bag.off
    e.handlers(RegCounted).size.should eq 0
  end
end
