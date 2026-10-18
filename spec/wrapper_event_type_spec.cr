require "./spec_helper"

EventHandler.event TypedAEvent, s : String
EventHandler.event TypedBEvent, n : Int32

class TypedASubEvent < TypedAEvent; end

module EventHandler
  class TestWrapperType
    include ::EventHandler
  end

  describe Wrapper do
    it "records the event type its handler accepts" do
      w = TypedAEvent::Wrapper.new { }
      w.event_type.should eq TypedAEvent
      erased = w.unsafe_as(::EventHandler::Wrapper(::Proc(::EventHandler::Event, ::Nil)))
      erased.event_type.should eq TypedAEvent
    end

    it "refuses registration for an event its handler cannot take" do
      c = TestWrapperType.new
      sub = c.on(TypedAEvent) { |e| e.s.size; nil }
      expect_raises(ArgumentError, /TypedAEvent cannot be registered for TypedBEvent/) do
        c.on TypedBEvent, sub
      end
      w = sub.wrapper.should_not be_nil
      expect_raises(ArgumentError) { c.on TypedBEvent, w }
      c.has_handlers?(TypedBEvent).should be_false
      # Not even an ancestor's handler in the other direction.
      expect_raises(ArgumentError) { c.on TypedAEvent, c.on(TypedASubEvent) { } }
    end

    it "accepts a wrapper built for an ancestor event" do
      c = TestWrapperType.new
      seen = [] of String
      sub = c.on(TypedAEvent) { |e| seen << e.class.name }
      c.on TypedASubEvent, sub
      c.emit TypedASubEvent, "x"
      seen.should eq ["TypedASubEvent"]
      any = ::EventHandler::Wrapper(::Proc(::EventHandler::Event, ::Nil)).new { |e| seen << "any" }
      c.on TypedBEvent, any
      c.emit TypedBEvent, 1
      seen.should eq ["TypedASubEvent", "any"]
    end
  end
end
