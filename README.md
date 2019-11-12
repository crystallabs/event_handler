[![Build Status](https://travis-ci.com/crystallabs/event_handler.svg?branch=master)](https://travis-ci.com/crystallabs/event_handler)
[![Version](https://img.shields.io/github/tag/crystallabs/event_handler.svg?maxAge=360)](https://github.com/crystallabs/event_handler/releases/latest)
[![License](https://img.shields.io/github/license/crystallabs/event_handler.svg)](https://github.com/crystallabs/event_handler/blob/master/LICENSE)

# EventHandler

EventHandler is an event library for Crystal.

It supports:

1. Defining events
1. Emitting events
1.  handlers for emitted events

Each handler can run synchronously or asynchronously, run one or more times,
and be added at the beginning or end of queue, or into a specific position.

## Installation

Add the dependency to `shard.yml`:

```yaml
dependencies:
  event_handler:
    github: crystallabs/event_handler
    version: 0.8.0
```

## Usage in a nutshell

Here is a basic example that defines and emits events. More detailed usage instructions are provided further below.

```crystal
require "event_handler"

# Define an event
EventHandler.event ClickedEvent, x : Int32, y : Int32

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
EventHandler.event ClickedEvent, x : Int32, y : Int32
```

If additional modification to the class is necessary, class can be reopened:

```crystal
EventHandler.event ClickedEvent, x : Int32, y : Int32

class ClickedEvent < EventHandler::Event
  property test : String?
end
```

Or the whole event class can be created manually; it only needs to inherit from `EventHandler::Event`:

```crystal
class ClickedEvent < EventHandler::Event
  getter x : Int32
  getter y : Int32
  property test : String?
  def initialize(@x, @y)
  end
end
```

### Adding event handlers

Event handlers can be added in a number of ways. Each handler must return a Bool.

Using a block:

```crystal
my = MyClass.new

my.on(ClickedEvent) do |e|
  true
end
```

Using a Proc:

```crystal
my = MyClass.new

# With Proc ->(){} syntax
handler = ->(e : ClickedEvent) do
  true
end

# With Proc.new syntax
handler = Proc(ClickedEvent, Bool).new do |e|
  true
end

my.on ClickedEvent, handler
```

Using an aliased type for Proc called `Handler`, eliminating the need to repeat type information:

```crystal
my = MyClass.new

handler = ClickedEvent::Handler.new do |e|
  true
end

my.on ClickedEvent, handler
```

Using an existing method:

```crystal
my = MyClass.new

def on_clicked(e : ClickedEvent)
  true
end

my.on ClickedEvent, ->on_clicked(ClickedEvent)
```

Using a variation of the last example, where if an object method is used, `self` is preserved as expected:

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

Using a handler "wrapper" object explicitly (otherwise it would be created and used implicitly):

```crystal
handler = ->(e : ClickedEvent) do
  true
end
wrapper = EventHandler::Wrapper.new(handler: handler, once: false, async: false, at: -1)

my.on ClickedEvent, wrapper
```

Using a variation of the last example with an aliased type for Wrapper, with block or Proc:

```crystal
# With block
wrapper = ClickedEvent::Wrapper.new(once: false, async: false, at: -1) do |e|
  true
end

# With Proc
handler = ->(e : ClickedEvent) do
  true
end
wrapper = ClickedEvent::Wrapper.new(handler: handler, once: false, async: false, at: -1)

my.on ClickedEvent, wrapper
```

Using a variation of the last example, where wrapper object is obtained from a call
to `on()` and then reused:

```crystal
handler = ->(e : ClickedEvent) do
  true
end

wrapper = my.on ClickedEvent, handler

my.on ClickedEvent, wrapper
```

#### Event handler options

All of the above methods for adding handlers support arguments `once`, `async`, and `at`.

`once` specifies whether the handler should run only once and then be automatically removed.
Default is false. In the future this option may be replaced with `times` which specifies
how many times to run before being removed.

`async` specifies whether a handler should run synchronously or asynchronously. If
no specific value is provided, global default from `EventEmitter.async` is used.
Default (`EventEmitter.async?`) is false. You can either modify this default,
or specify `async` on a per-`on()` basis.

`at` specifies the index in the list of handlers where new handler should be inserted.
While it is possible to specify the exact position, usually this value is
`0` (`EventEmitter.at_beginning`) to insert at the beginning or `-1` (`EventEmitter.at_end`)
to insert at the end of list. Default is `EventEmitter.at_end`.

As a convenience for adding handlers that should run only once, there is a method
named `once` available instead of the usual `on`. These two calls are equivalent:

```crystal
my.on ClickedEvent, handler, once: true, async: true, at: -1

my.once ClickedEvent, handler, async:true, at: -1
```

### Emitting events

Events can be emitted by calling `emit` and listing arguments one after another:

```crystal
my.emit ClickedEvent, 10, 20
```

Or by creating an event instance and packing arguments in it:

```crystal
my.emit ClickedEvent, ClickedEvent.new(10, 20)
```

In either case, the handler methods will receive one argument - the event object
with packed arguments.

Emitting an event returns a value. If all handlers run synchronously, the return
value will be a Bool, indicating whether all handlers have completed successfully
(`true`) or not (`false`).

If one or more handlers run asynchronously, the return value is immediately `nil`.

### Handling events

As mentioned, handlers always receive one argument - an Event subclass with packed arguments.

When an event is emitted using any of available variants, such as:

```crystal
my.emit ClickedEvent, ClickedEvent.new x: 10, y: 20
```

The arguments are directly accessible as getters on the event object:

```
my.on(ClickedEvent) do |e|
  puts "Clicked on position x=#{e.x}, y=#{e.y}"
  true
end
```

All handlers must return a Bool as their return value, indicating success (`true`)
or failure (`false`).

### Listing event handlers

To look up the current list of installed handlers for an event, use `handlers`:

```crystal
my.handlers ClickedEvent
```

Please note that `handlers` exposes the Array containing the list of handlers.

Modifying this array will directly modify the list of handlers defined for an event. This should only be done with due caution.

### Removing event handlers

Event handlers can be removed in one of five ways:

By handler Proc:

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

By handler wrapper object:

```crystal
handler = ClickedEvent::Handler.new {
  true
}

wrapper = my.on ClickedEvent, handler
my.off ClickedEvent, wrapper
```

Internally, handlers are always removed from events by removing their wrapper
object.

When wrappers are created implicitly by `on()`, each handler
is given a different wrapper object even if added multiple times. A call to
`off()` will find the first wrapper instance of this handler
and remove it from the list.
If a handler is added to an event more than once, it is necessary to call
`off()` multiple times to remove all instances.

When handlers are added by passing wrappers directly, adding a handler multiple
times results in multiple identical wrapper objects present in the list.
When `off()` is used to remove such handlers, each group of
identical wrapper instances is removed at once and `RemoveHandlerEvent`
is invoked once for each group with the last removed instance as argument.

Whether `off(Event, handler | hash)` should find the first wrapper instance (like
it does now) or all instances, and whether `off(Event, wrapper)`
should remove all identical wrappers (like it does now) or only the
first one, is still being considered.

By index:

```crystal
my.off ClickedEvent, at: 0
```

By removing all handlers at once:

```crystal
my.remove_all_handlers ClickedEvent
```

When `remove_all_handlers` is used, `RemoveHandlerEvent`s will be emitted as
expected, and multiple identical wrappers will be removed according to the
above-documented behavior.
If `RemoveHandlerEvent` events should be disabled when using `remove_all_handlers`,
see `EventEmitter.emit_on_remove_all?` and `EventEmitter.emit_on_remove_all=`.

### Meta events

There are four built-in events:

`AddHandlerEvent` - Event emitted whenever a handler is added for any event, including itself.

`RemoveHandlerEvent` - Event emitted whenever a handler is removed from any event, including itself.

`AnyEvent` - Event emitted on any event. Adding a handler for this event allows listening for all emitted events and their arguments.

`ExceptionEvent` - Event used for emitting exceptions. If an exception is emitted using this event and there are no handlers subscribed to it, the exception will instead be raised. Appropriateness of this event in the system core is still being evaluated.

As mentioned, a wrapper object is implicitly created around a handler on every `on()`, to encapsulate the handler and its
subscription options (the values of `once?`, `async?`, and `at`).
When `AddHandlerEvent` or `RemoveHandlerEvent` are emitted, they are invoked with the handlers's `Wrapper` object as argument.
This allows listeners on these two meta events full insight into the added or removed handlers and their settings.

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
