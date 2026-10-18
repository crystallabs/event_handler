require "./spec_helper"

EventHandler.event ClampEvent, n : Int32

module EventHandler
  class TestClamp
    include ::EventHandler
  end

  describe EventHandler do
    it "clamps a replayed insertion position to the list's bounds" do
      c = TestClamp.new
      order = [] of Int32
      c.on(ClampEvent) { order << 1 }
      c.on(ClampEvent) { order << 2 }
      sub = c.on(ClampEvent, at: 2) { order << 3 }
      c.remove_all_handlers ClampEvent
      c.on ClampEvent, sub # `at: 2` on an empty list
      c.on(ClampEvent, at: 99) { order << 4 }
      c.on(ClampEvent, at: -99) { order << 0 }
      c.emit ClampEvent, 1
      order.should eq [0, 3, 4]
    end
  end
end
