require "../src/event_handler"

abstract class EventWithRetval < ::EventHandler::Event
  property return_value : Int32 = 0
end

class_record ClickedEvent < EventWithRetval, x : Int32, y : Int32

class DoubleClickedEvent < ClickedEvent
end

class TripleClickedEvent < DoubleClickedEvent
  def initialize(@x : Int32, @y : Int32)
    @z = 0
  end

  def initialize(@x : Int32, @y : Int32, @z : Int32)
  end
end

class My
  include EventHandler

  def initialize
    on(ClickedEvent) { |e| e.return_value = 1 }
    on(DoubleClickedEvent) { |e| e.return_value = 2 }
    on(TripleClickedEvent) { |e| e.return_value += 3 }
  end
end

my = My.new

p my.emit(ClickedEvent, 1, 2).return_value # => 1

p my.emit(DoubleClickedEvent, 3, 4).return_value # => 2

p my.emit(TripleClickedEvent, 7, 8, 9).return_value # => 3
