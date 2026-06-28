require "./spec_helper"

EventHandler.event OffWrapperEvent, x : Int32

module EventHandler
  class TestOffWrapper
    include ::EventHandler
  end

  describe EventHandler do
    # `off(type, wrapper)` must remove the handler both when given the concrete
    # wrapper returned by `on` and when given the *erased*
    # `Wrapper(Proc(Event, Nil))` handed to `AddHandlerEvent`/`RemoveHandlerEvent`
    # handlers. The latter used to silently remove nothing, because `Array#delete`
    # compares the stored concrete-typed element against the erased type with
    # `Reference#==`, whose identity branch (`==(other : self)`) no longer applies.
    it "removes a handler given the concrete wrapper returned by on" do
      c = TestOffWrapper.new
      w = c.on(OffWrapperEvent) { |e| e.x; true }
      c.on(OffWrapperEvent) { |e| e.x; true }
      c.handlers(OffWrapperEvent).size.should eq 2

      removed = c.off(OffWrapperEvent, w)
      removed.should_not be_nil
      c.handlers(OffWrapperEvent).size.should eq 1
    end

    it "removes a handler given the erased wrapper from AddHandlerEvent" do
      c = TestOffWrapper.new
      captured = nil
      c.on(AddHandlerEvent) { |e| captured = e.wrapper; nil }
      c.on(OffWrapperEvent) { |e| e.x; true }

      c.handlers(OffWrapperEvent).size.should eq 1
      captured.should_not be_nil

      removed = c.off(OffWrapperEvent, captured.not_nil!)
      removed.should_not be_nil
      c.handlers(OffWrapperEvent).size.should eq 0
    end

    it "returns nil and removes nothing when the wrapper is absent" do
      c = TestOffWrapper.new
      w = c.on(OffWrapperEvent) { |e| e.x; true }
      c.off(OffWrapperEvent, w)
      # Off again: already gone.
      c.off(OffWrapperEvent, w).should be_nil
      c.handlers(OffWrapperEvent).size.should eq 0
    end
  end
end
