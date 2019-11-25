require "./spec_helper"

EventHandler.event ClickedEvent, x : Int32, y : Int32

EventHandler.event OneEvent, x : Int32

EventHandler.event TwoEvent, x : Int32
class TwoEvent < EventHandler::Event
  property y : Int32?
  def initialize(@x,@y) end
end

class ThreeEvent < EventHandler::Event
  property x : Int32
  property y : Int32
  def initialize(@x,@y=1) end
end

module EventHandler

  class TestReopen
    include ::EventHandler
  end

  describe EventHandler do
    it "works" do
      c = TestReopen.new
      count = 0

      c.on(OneEvent)   { |e| count += 1; e.x; true }
      c.on(TwoEvent)   { |e| count += 1; e.x; e.y; true }
      c.on(ThreeEvent) { |e| count += 1; e.x; e.y; true }

      c.emit OneEvent, 1
      c.emit TwoEvent, 2
      c.emit ThreeEvent, 3

      count.should eq 3
    end
  end
end

