[![Build Status](https://travis-ci.com/crystallabs/event_handler.svg?branch=master)](https://travis-ci.com/crystallabs/event_handler)
[![Version](https://img.shields.io/github/tag/crystallabs/event_handler.svg?maxAge=360)](https://github.com/crystallabs/event_handler/releases/latest)
[![License](https://img.shields.io/github/license/crystallabs/event_handler.svg)](https://github.com/crystallabs/event_handler/blob/master/LICENSE)

# EventHandler

EventHandler is a full-featured event library for Crystal.

It supports:

1. Defining events
1. Emitting events
1. Adding and removing handlers for emitted events

Each handler can run synchronously or asynchronously, run one or more times,
and be added at the beginning or end of queue, or into a specific position.

It also supports subclassing events, sending events through Channels,
and waiting for events.

## Installation

Add the dependency to `shard.yml`:

```yaml
dependencies:
  event_handler:
    github: crystallabs/event_handler
    version: 0.10.0
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
my.off MyClass::TestEvent, handler
my.remove_all_handlers ClickedEvent
```

## Documentation

### Defining events

An event can be defined via the convenient `event` macro or manually.

Using `event` creates an event class which inherits from base class `EventHandler::Event`:

```crystal
EventHandler.event ClickedEvent, x : Int32, y : Int32
```

It is a shorthand for the following line:

```crystal
class_record ClickedEvent < ::EventHandler::Event, x : Int32, y : Int32
```

`class_record` is EventHandler's variant of Crystal's `record` macro; it creates classes instead of structs.

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

Subclassing also works as expected:

```crystal
EventHandler.event ClickedEvent, x : Int32, y : Int32

class DoubleClickedEvent < ClickedEvent
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
my = MyClass.new

handler = ->(e : ClickedEvent) do
  true
end
wrapper = EventHandler::Wrapper.new(handler: handler, once: false, async: false, at: -1)

my.on ClickedEvent, wrapper
```

Using a variation of the last example with an aliased type for Wrapper:

```crystal
my = MyClass.new

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
to `on()` and then reused to add the handler the second time:

```crystal
my = MyClass.new

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
or specify `async` on a per-`on` basis.

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

As mentioned, handlers always receive one argument - the event object with packed arguments.

When an event is emitted using any of the available variants, such as:

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

### Inspecting event handlers

To inspect the current list of installed handlers for an event, use `handlers`:

```crystal
my.handlers ClickedEvent

my.handlers(ClickedEvent).size

my.handlers(ClickedEvent).empty?
```

Please note that `handlers` exposes the Array containing the list of handlers.

Modifying the array will directly modify the list of handlers defined for an event. This should only be done with due caution.

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

When wrappers are created implicitly by `on`, each invocation of `on`
gives handler a new wrapper object even if it is added multiple times for
the same event. A call to
`off()` will find the first wrapper instance of this handler
and remove it from the list.
If a handler is added to an event more than once, it is necessary to call
`off()` multiple times to remove all instances.

When handlers are added by using their wrappers directly, adding a handler multiple
times results in multiple identical wrapper objects present in the list.
When `off()` is used to remove such handlers, each group of
identical wrapper instances is removed at once and `RemoveHandlerEvent`
is invoked once for each group with the last removed instance as argument.

Whether `off(Event, handler | hash)` should be removing handlers by
wrapper (like it does now) or by handler, and whether `off()` should remove
all instances (like it does now) or at most one, is still being considered.

By handler index in the `handlers` Array:

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
If emitting `RemoveHandlerEvent` events should be disabled for `remove_all_handlers`,
see `EventEmitter.emit_on_remove_all?` and `EventEmitter.emit_on_remove_all=`.

### Meta Events

There are four built-in events:

`AddHandlerEvent` - Event emitted whenever a handler is added for any event, including itself.

`RemoveHandlerEvent` - Event emitted whenever a handler is removed from any event, including itself.

`AnyEvent` - Event emitted on any event. Adding a handler for this event allows listening for all emitted events and their arguments.

`ExceptionEvent` - Event used for emitting exceptions. If an exception is emitted using this event and there are no handlers subscribed to it, the exception will instead be raised. Appropriateness of this event in the system core is still being evaluated.

As mentioned, a wrapper object is implicitly created around a handler on every `on`, to encapsulate the handler and its
subscription options (the values of `once?`, `async?`, and `at`).
When `AddHandlerEvent` or `RemoveHandlerEvent` are emitted, they are invoked with the
handlers' `Wrapper` object as argument.
This allows listeners on these two meta events full insight into the added or removed handlers and their settings.

### Channels

Emitted events can also be sent through Channels. EventHandler comes with
convenience classes and functions for this purpose:

Channels can be created with Channel(T) or an aliased type:

```crystal
# With Channel(T)
channel = Channel(ClickedEvent).new

# With an aliased type
channel = ClickedEvent::Channel.new
```

Sending of emitted events through Channels can be requested with `on` as usual.
Invoking `on` with a Channel argument will implicitly create a handler which
forwards emitted events to the Channel:

```crystal
my.on ClickedEvent, channel, async: true
```

The same behavior can also be implemented manually:

```crystal
channel = Channel(ClickedEvent).new

my.on(ClickedEvent, async: true) do |e|
  channel.send e
end
```

A complete example:

```crystal
require "event_handler"

EventHandler.event ClickedEvent, x : Int32, y : Int32

class My
  include EventHandler
end
my = My.new

# Create a channel, wait for event, and print it
channel = ClickedEvent::Channel.new
my.once ClickedEvent, channel, async: true
my.emit(ClickedEvent, 1,2)
p channel.receive

# Same as above, implemented manually
channel = Channel(ClickedEvent).new
my.once(ClickedEvent, async: true) do |e|
  channel.send e
  true
end
my.emit(ClickedEvent, 1,2)
p channel.receive
```

### Waiting for events

Using Channels, it is also possible to wait for events.

The above example already shows blocking on `channel.receive`.
The same effect can be achieved using `wait` and
avoiding visible use of Channels:

```crystal
e = my.wait(ClickedEvent)
```

`wait` can also be invoked with a block or Proc:

```crystal
my.wait(ClickedEvent) do |e|
  true
end
```

The accepted syntax and arguments for `wait` are the same as
for `once`.

When waiting for events with a block or Proc, two handlers
are involved:

The first, visible one is the handler which is provided to
`wait`, containing code to execute once the event arrives.
`wait` argument *async* controls whether the handler will
run synchronously or asynchronously after the event has been
waited.

The other, implicit one is the handler automatically created
and added to the list of event handlers. Once the event is
emitted and this handler runs, it will forward the received
event into the Channel.
`wait` argument *async_send* controls whether the event emitter
will block on `channel.send` or it will execute the send in
a new fiber.

### Subclassing

Event classes can be subclassed with no restrictions:

```crystal
require "event_handler"

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
    on(ClickedEvent)       {|e| p e; true }
    on(DoubleClickedEvent) {|e| p e; true }
    on(TripleClickedEvent) {|e| p e; true }
  end
end
my = My.new

my.emit ClickedEvent, 1, 2

my.emit DoubleClickedEvent, 3, 4

my.emit TripleClickedEvent, 5, 6
my.emit TripleClickedEvent, 7, 8, 9
```

### Custom behavior

The behavior of events can be modified in many ways.

Here is an example which, based on a single event definition, creates three events
and emits all three when the main event is emitted:

```crystal
require "event_handler"

macro extended_event(e, *args)
  # Regular event definition as with the standard `event()` macro
  class_record {{e.id}} < ::EventHandler::Event{% if args.size > 0 %}, {{ *args }}{% end %}

  # Subclassed event definition. It accepts same arguments as parent event
  class {{e.id}}::Subclass < {{e.id}}; end

  # Related event definition. Its signature is different; it accepts the
  # complete main event as argument
  class_record {{e.id}}::Related < ::EventHandler::Event, event : {{e.id}}

  # A way for the main event to retrieve its subclassed event class
  def {{e.id}}.subclass; {{e.id}}::Subclass end

  # A way for the main event to retrieve its related event class
  def {{e.id}}.related; {{e.id}}::Related end
end

# Define the main event. Based on the above, it automatically creates
# ClickedEvent, ClickedEvent::Subclass, and ClickedEvent::Related.
extended_event ClickedEvent, x : Int32, y : Int32

class My
  include EventHandler

  def initialize
    # Install event handlers
    on(ClickedEvent)           {|e| p e; true }
    on(ClickedEvent::Subclass) {|e| p e; true }
    on(ClickedEvent::Related)  {|e| p e; true }
  end

  # Override emit() to insert custom logic
  def emit(type, obj : EventHandler::Event)
    _emit EventHandler::AnyEvent, type, obj

    ret = true

    ret &&= _emit type, obj
    ret &&= _emit type.subclass, obj
    ret &&= _emit type.related, obj

    ret
  end
end
my = My.new

my.emit ClickedEvent, 1, 2

#<ClickedEvent:0x7fca444d5eb0 @x=1, @y=2>
#<ClickedEvent:0x7fca444d5eb0 @x=1, @y=2>
#<ClickedEvent::Related:0x7fca444d4b80 @event=#<ClickedEvent:0x7fca444d5eb0 @x=1, @y=2>>
```

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

## Other projects

List of interesting or similar projects in no particular order:

- https://github.com/Papierkorb/cute - Event-centric pub/sub model for objects inspired by the Qt framework

- https://github.com/hugoabonizio/event_emitter.cr - Idiomatic asynchronous event-driven architecture
