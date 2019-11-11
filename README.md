[![Build Status](https://travis-ci.com/crystallabs/event_handler.svg?branch=master)](https://travis-ci.com/crystallabs/event_handler)
[![Version](https://img.shields.io/github/tag/crystallabs/event_handler.svg?maxAge=360)](https://github.com/crystallabs/event_handler/releases/latest)
[![License](https://img.shields.io/github/license/crystallabs/event_handler.svg)](https://github.com/crystallabs/event_handler/blob/master/LICENSE)

# EventHandler

EventHandler is an event library for Crystal.

It supports:

1. Defining events on per-class level
1. Emitting events on objects
1. Adding handlers for the emitted events

Each handler can run synchronously or asynchronously, run one or more times,
and be added at the beginning or end of queue, or into a specific position.

## Usage in a nutshell

Here is a basic example that defines and emits events. More detailed usage instructions are provided further below.

```crystal
require "event_handler"

# Define an event
event TestEvent, message : String, status : Bool

# Create an event-enabled class
class MyClass
  include EventHandler
  event ClickedEvent, x : Int32, y : Int32
end
my = MyClass.new

# Add a block as event handler
my.on(TestEvent) do |e|
  puts "Activated on #{e.class}. Message is '#{e.message}' and status is #{e.status}"
  true
end

# And a Proc as event handler
handler = ->(e : MyClass::ClickedEvent) do
  puts "Clicked on position x=#{e.x}, y=#{e.y}"
  true
end
my.on MyClass::ClickedEvent, handler

# Emit events
my.emit TestEvent, "Hello, World!", true
my.emit MyClass::ClickedEvent, 10, 20

# Remove handlers
my.remove_all_handlers TestEvent
my.off MyClass::ClickedEvent, handler
```

## Documentation

### Defining events

An event can be defined via the convenient `event` macro or manually.

Using `event` creates an event class which inherits from base class `EventHandler::Event`:

```crystal
event ClickedEvent, x : Int32, y : Int32
```

If additional modification to the class is necessary, class can be reopened:

```crystal
event ClickedEvent, x : Int32, y : Int32

class ClickedEvent < ::EventHandler::Event
  property test : String?
end
```

Or the whole event class can be created manually; it only needs to inherit from `EventHandler::Event`:

```crystal
class ClickedEvent < ::EventHandler::Event
  getter x : Int32
  getter y : Int32
  property test : String
  def initialize(@x, @y)
  end
end
```

### Adding event handlers

Event handlers can be added in four different ways. Each handler must return a Bool.

As a block:

```crystal
my = MyClass.new

my.on(TestEvent) do |e|
  true
end
```

As a Proc:

```crystal
my = MyClass.new

handler = ->(e : MyClass::ClickedEvent) do
  true
end

my.on MyClass::ClickedEvent, handler
```

As a pre-created Proc, eliminating the need to repeat type information:

```crystal
my = MyClass.new

handler = ClickedEvent::Handler.new do |e|
	true
end

c.on ClickedEvent, handler
```

Or using an existing function:

```crystal
my = MyClass.new

def on_clicked(e : MyClass::ClickedEvent)
	true
end

my.on ClickedEvent, ->on_clicked(MyClass::ClickedEvent)
```

And as a variation of the last example, if an object method is used, `self` is preserved as expected:

```crystal
class MyClass
  include EventHandler
  event ClickedEvent, x : Int32, y : Int32

  def on_clicked(e : ClickedEvent)
    p :clicked, e.x, e.y, self
    true
  end
end
my = MyClass.new

my.on MyClass::ClickedEvent, ->my.on_clicked(MyClass::ClickedEvent)
```

### Emitting events

Events can be emitted by calling `emit` and listing arguments one after another:

```crystal
my.emit TestEvent, 10, 20
```

Or by packing them into an event object instance with arguments packed inside it.

```crystal
my.emit TestEvent, TestEvent.new(10, 20)
```

### Listing event handlers

If you need to look up the list of event handlers, use `handlers`:

```crystal
```

Please note that `handlers` exposes the Array containing the list of handlers.

Modifying this array will directly modify the list of handlers defined for an event, although this should be done with due caution.

### Removing event handlers

Event handlers can be removed in one of four ways:

By handler Proc itself:

```crystal
handler = ClickedEvent::Handler.new do |e|
	true
end

c.on ClickedEvent, handler
c.off ClickedEvent, handler
```

By handler hash:

```crystal
handler = ClickedEvent::Handler.new do |e|
	true
end

hash = handler.hash

c.on ClickedEvent, handler
c.off ClickedEvent, hash
```

By handler wrapper:

```crystal
handler = ClickedEvent::Handler.new {
  true
}

wrapper = c.on ClickedEvent, handler
x.off ClickedEvent, wrapper
```

By removing all handlers at once:

```crystal
x.remove_all_handlers ClickedEvent
```

Note: using `remove_all_handlers` does not trigger a `RemoveHandlerEvent` for removed handlers.

### Meta events

There are four built-in events which do not need to be defined manually:

`AddHandlerEvent` - Event emitted whenever a handler is added for any event, including itself.

`RemoveHandlerEvent` - Event emitted whenever a handler is removed from any event, including itself.

`AnyEvent` - Event emitted on every other event. Adding a handler for this event allows listening for all emitted events and their arguments.

`ExceptionEvent` - Event used for emitting exceptions. If an exception is emitted using this event and there are no handlers subscribed to it, the exception will instead be raised. Usefulness of this event in the system core is still being evaluated.

## API documentation

Run `crystal docs` as usual, then open file `docs/index.html`.

Also, see examples in the directory `examples/`.

## Testing

Run `crystal spec` as usual.

Also, see examples in the directory `examples/`.

## Thanks

* All the fine folks on FreeNode IRC channel #crystal-lang and on Crystal's Gitter channel https://gitter.im/crystal-lang/crystal

* Blacksmoke16 for a workable event model design

* Asterite, Absolutejam, and Tenebrousedge for additional discussion

## Related projects

List of interesting or related projects in no particular order:

- https://github.com/hugoabonizio/event_emitter.cr - Idiomatic asynchronous event-driven architecture
