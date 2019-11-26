require "../src/event_handler"

macro extended_event(e, *args)
  class_record {{e.id}} < ::EventHandler::Event{% if args.size > 0 %}, {{ *args }}{% end %}

  class {{e.id}}::Subclass < {{e.id}}; end

  class_record {{e.id}}::Related < ::EventHandler::Event, event : {{e.id}} # or ::EventHandler::Event

  def {{e.id}}.subclass; {{e.id}}::Subclass end

  def {{e.id}}.related; {{e.id}}::Related end
end

extended_event ClickedEvent, x : Int32, y : Int32

class My
  include EventHandler

  def initialize
    on(ClickedEvent)           {|e| p e }
    on(ClickedEvent::Subclass) {|e| p e }
    on(ClickedEvent::Related)  {|e| p e }
  end

  def emit(type, obj : EventHandler::Event)
    _emit EventHandler::AnyEvent, obj

    _emit type, obj
    _emit type.subclass, obj
    _emit type.related, obj

  end
end
my = My.new

my.emit ClickedEvent, 1, 2
