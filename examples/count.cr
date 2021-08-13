require "../src/event_handler"

abstract class EventWithCount < ::EventHandler::Event
  class_property count : UInt64 = 0

  def initialize
    @@count += 1
  end
end

class ClickedEvent < EventWithCount
  getter x : Int32
  getter y : Int32

  def initialize(@x, @y)
    super()
  end
end

class My
  include EventHandler
end

my = My.new

20.times { my.emit ClickedEvent, 1, 2 }

p ClickedEvent.count # => 20
