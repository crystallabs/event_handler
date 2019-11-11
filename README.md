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
event ClickedEvent, x : Int32, y : Int32

# Create an event-enabled class
class MyClass
  include EventHandler
  event TestEvent, message : String, status : Bool
end
my = MyClass.new

# Add a block as event handler
my.on(ClickedEvent) do |e|
  puts "Clicked on position x=#{e.x}, y=#{e.y}"
  true
end

# And a Proc as event handler
handler = ->(e : MyClass::TestEvent) do
  puts "Activated on #{e.class}. Message is '#{e.message}' and status is #{e.status}"
  true
end
my.on MyClass::TestEvent, handler

# Emit events
my.emit ClickedEvent, 10, 20
my.emit MyClass::TestEvent, "Hello, World!", true

# Remove handlers
my.remove_all_handlers ClickedEvent
my.off MyClass::TestEvent, handler
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
  property test : String?
  def initialize(@x, @y)
  end
end
```

### Adding event handlers

Event handlers can be added in four different ways. Each handler must return a Bool.

As a block:

```crystal
my = MyClass.new

my.on(ClickedEvent) do |e|
  true
end
```

As a Proc:

```crystal
my = MyClass.new

handler = ->(e : ClickedEvent) do
  true
end

my.on ClickedEvent, handler
```

As a pre-created Proc, eliminating the need to repeat type information:

```crystal
my = MyClass.new

handler = ClickedEvent::Handler.new do |e|
  true
end

my.on ClickedEvent, handler
```

Or using an existing function:

```crystal
my = MyClass.new

def on_clicked(e : ClickedEvent)
  true
end

my.on ClickedEvent, ->on_clicked(ClickedEvent)
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

my.on ClickedEvent, ->my.on_clicked(ClickedEvent)
```

#### Event handler options

All of the above methods for adding handlers support arguments `once`, `async`, and `at`.

`once` specifies whether the handler should run only once and then be automatically removed.
Default is false. In the future this option may be replaced with `times` which specifies
how many times to run before being removed.

`async` specifies whether a handler should run synchronously or asynchronously. If
no specific value is provided, global default from `EventEmitter.async` is used.
Default (`EventEmitter.async?`) is false. You can either modify this default,
or specify `async` on a per-call basis.

`at` specifies the index in the handlers list where new handler should be inserted.
While it is possible to specify the exact position, usually this value is `0` to
insert at the beginning or `-1` to insert at the end. Default is `-1`.

As a convenience for adding handlers that should run only once, there is a method
named `once` available instead of the usual `on`. These two calls are equivalent:

```crystal
my.on ClickedEvent, handler, once: true, async: true, at: -1

my.once ClickedEvent, handler, async:true. at: -1
```

### Emitting events

Events can be emitted by calling `emit` and listing arguments one after another:

```crystal
my.emit ClickedEvent, 10, 20
```

Or by creating an event object instance and packing arguments in it:

```crystal
my.emit ClickedEvent, ClickedEvent.new(10, 20)
```

In either case, the handler methods will receive one argument - the object
instance with packed arguments.

Emitting an event returns a value. If all handlers ran synchronously, the return
value will be Bool, indicating whether all handlers have completed successfully
(`true`) or not (`false`).

If one or more handlers ran asynchronously, the return value is always `nil`.

### Handling events

Handlers will always receive one argument, which is some Event subclass, packed with emitted arguments.

When an event is emitted using any of available variants, such as:

```crystal
my.emit ClickedEvent, ClickedEvent.new x: 10, y: 20
```

All handlers will receive instance of the event, with arguments being directly accessible as getters:

```
my.on(ClickedEvent) do |e|
  puts "Clicked on position x=#{e.x}, y=#{e.y}"
  true
end
```

### Listing event handlers

If you need to look up the list of event handlers, use `handlers`:

```crystal
my.handlers ClickedEvent
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

my.on ClickedEvent, handler
my.off ClickedEvent, handler
```

By handler hash:

```crystal
handler = ClickedEvent::Handler.new do |e|
  true
end

hash = handler.hash

my.on ClickedEvent, handler
my.off ClickedEvent, hash
```

By handler wrapper:

```crystal
handler = ClickedEvent::Handler.new {
  true
}

wrapper = my.on ClickedEvent, handler
my.off ClickedEvent, wrapper
```

By removing all handlers at once:

```crystal
my.remove_all_handlers ClickedEvent
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
