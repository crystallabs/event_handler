require "../src/event_handler"

EventHandler.event ClickedEvent, x : Int32, y : Int32

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
    on(ClickedEvent) { |e| p e }
    on(DoubleClickedEvent) { |e| p e }
    on(TripleClickedEvent) { |e| p e }
  end
end

my = My.new
my.emit ClickedEvent, 1, 2
my.emit DoubleClickedEvent, 3, 4
my.emit TripleClickedEvent, 5, 6
my.emit TripleClickedEvent, 7, 8, 9
