require "./spec_helper"

EventHandler.event ClickedEvent, x : Int32, y : Int32

module EventHandler
  class TestErasedWrapper
    include ::EventHandler
  end

  describe EventHandler do
    it "re-adds a wrapper given in the erased spelling AddHandlerEvent and Subscription#wrapper carry" do
      c = TestErasedWrapper.new
      count = 0
      subscription = c.on(ClickedEvent) { count += 1 }
      # Statically `Wrapper(Proc(Event, Nil))`, not the concrete type the list holds.
      erased = subscription.wrapper.should_not be_nil
      typeof(erased).should eq ::EventHandler::Wrapper(::Proc(::EventHandler::Event, ::Nil))

      c.on ClickedEvent, erased
      c.handlers(ClickedEvent).size.should eq 2
      c.emit ClickedEvent, 1, 2
      count.should eq 2

      # The same object as the stored concrete-typed wrapper, so identity removal drops both copies.
      c.off(ClickedEvent, erased).should be erased
      c.handlers(ClickedEvent).should be_empty
    end

    it "re-adds a wrapper handed to an AddHandlerEvent listener" do
      c = TestErasedWrapper.new
      seen = [] of ::EventHandler::Wrapper(::Proc(::EventHandler::Event, ::Nil))
      c.on(AddHandlerEvent) { |e| seen << e.wrapper if e.event == ClickedEvent }
      c.on(ClickedEvent) { }
      seen.size.should eq 1
      c.on ClickedEvent, seen.first
      c.handlers(ClickedEvent).size.should eq 2
    end
  end
end
