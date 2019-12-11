require "../src/event_handler"

abstract class EventWithCount < ::EventHandler::Event
  class_property count : UInt64 = 0

  def emit(*arg)
    @@count += 1
    super *arg
  end
end

class ClickedEvent < EventWithCount
  getter x : Int32
  getter y : Int32
  def initialize(@x, @y)
    super()
  end
end

class My; include EventHandler end
my = My.new

4.times { my.emit ClickedEvent, 1, 2 }

p ClickedEvent.count # => 4
