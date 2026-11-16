require "./spec_helper"

EventHandler.event Bugs20Sized
EventHandler.event Bugs20Outer

# An event nested in another event class, sharing the last name component of
# the top-level `Bugs20Sized`.
class Bugs20Outer
  class Bugs20Sized < ::EventHandler::Event
  end
end

module EventHandler
  class TestBugs20Sugar
    include ::EventHandler
  end

  describe "on_<event> sugar" do
    it "subscribes to the top-level event when a nested event shares its name" do
      c = TestBugs20Sugar.new
      top = 0
      c.on_bugs20_sized { top += 1 }
      c.emit Bugs20Outer::Bugs20Sized
      top.should eq 0
      c.emit Bugs20Sized
      top.should eq 1
    end
  end
end
