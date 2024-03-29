[![Linux CI](https://github.com/crystallabs/event_handler/workflows/Linux%20CI/badge.svg)](https://github.com/crystallabs/event_handler/actions?query=workflow%3A%22Linux+CI%22+event%3Apush+branch%3Amaster)
[![Version](https://img.shields.io/github/tag/crystallabs/event_handler.svg?maxAge=360)](https://github.com/crystallabs/event_handler/releases/latest)
[![License](https://img.shields.io/github/license/crystallabs/event_handler.svg)](https://github.com/crystallabs/event_handler/blob/master/LICENSE)

# EventHandler

EventHandler is a full-featured event library for Crystal.

It supports:

1. Defining events
1. Defining handlers that will run in response to events
1. Emitting (triggering) events

Each handler can run synchronously or asynchronously, run one or more
times, and be added at the beginning or end of queue, or into a specific position.

Subclassing events is also supported, as well as sending events through Channels
and blocking/waiting for events.

## Installation

Add the dependency to `shard.yml`:

```yaml
dependencies:
  event_handler:
    github: crystallabs/event_handler
    version: ~> 1.0
```

## Usage in a nutshell

Here is a basic example that defines and emits events. More detailed usage instructions are provided further below.

```crystal
require "event_handler"

# Define an event named ClickedEvent with two arguments
EventHandler.event ClickedEvent, x : Int32, y : Int32

class MyClass
  include EventHandler

  def initialize
    # Define a handler that will run in response to the event
    on(::ClickedEvent) do |e|
      puts "Clicked on position x=#{e.x}, y=#{e.y}"
    end
  end
end

# Trigger the event on the object:
my = MyClass.new
my.emit ClickedEvent, 10, 20 #=> "Clicked on position x=10, y=20"
```

Or another example:

```cr
require "event_handler"

# Define an event inside a namespace (MyClass::TestEvent)
class MyClass
  include EventHandler
  event TestEvent, message : String, status : Bool
end

my = MyClass.new

# Add a Proc as event handler
handler = ->(e : MyClass::TestEvent) do
  puts "Activated on #{e.class}. Message is '#{e.message}' and status is #{e.status}"
end
my.on MyClass::TestEvent, handler

# Emit the event
my.emit MyClass::TestEvent, "Hello, World!", true
#=> Activated on MyClass::TestEvent. Message is 'Hello, World!' and status is true

# Remove the handler
my.off MyClass::TestEvent, handler

# Or remove all handlers for an event at once
my.off MyClass::TestEvent
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

(`class_record` is EventHandler's variant of Crystal's macro `record`; it creates classes instead of structs.)

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

Event handlers can be added in a number of ways.

Using a block:

```crystal
my = MyClass.new

my.on ClickedEvent do |e|
  p "Hello"
end
```

Using a Proc:

```crystal
my = MyClass.new

# With Proc ->(){} syntax
handler = ->(e : ClickedEvent) do
  p "Hello"
  nil
end

# With Proc.new syntax
handler = Proc(ClickedEvent, Nil).new do |e|
  p "Hello"
end

my.on ClickedEvent, handler
```

Using an aliased type for Proc called `Handler`, eliminating the need to repeat type information:

```crystal
my = MyClass.new

handler = ClickedEvent::Handler.new do |e|
  p "Hello"
end

my.on ClickedEvent, handler
```

Using an existing method:

```crystal
my = MyClass.new

def on_clicked(e : ClickedEvent) : Nil
  p "Hello"
end

my.on ClickedEvent, ->on_clicked(ClickedEvent)
```

Using a variation of the last example, where if an object method is used, `self` is preserved as expected:

```crystal
class MyClass
  include EventHandler
  event ClickedEvent, x : Int32, y : Int32

  def on_clicked(e : ClickedEvent)
    p "Hello", e.x, e.y, self
    nil
  end
end
my = MyClass.new

my.on ClickedEvent, ->my.on_clicked(ClickedEvent)
```

Using a handler "wrapper" object explicitly (otherwise it would be created and used implicitly):

```crystal
my = MyClass.new

handler = ->(e : ClickedEvent) do
  p "Hello"
  nil
end
wrapper = EventHandler::Wrapper.new(handler: handler, once: false, async: false, at: -1)

my.on ClickedEvent, wrapper
```

Using a variation of the last example with an aliased type for Wrapper:

```crystal
my = MyClass.new

# With block
wrapper = ClickedEvent::Wrapper.new(once: false, async: false, at: -1) do |e|
  p "Hello"
end

# With Proc
handler = ->(e : ClickedEvent) do
  p "Hello"
  nil
end
wrapper = ClickedEvent::Wrapper.new(handler: handler, once: false, async: false, at: -1)

my.on ClickedEvent, wrapper
```

Using a variation of the last example, where wrapper object is obtained from a call
to `on()` and then reused to add the same handler the second time:

```crystal
my = MyClass.new

handler = ->(e : ClickedEvent) do
  p "Hello"
  nil
end

wrapper = my.on ClickedEvent, handler

my.on ClickedEvent, wrapper
```

Using a Channel:

```crystal
my = MyClass.new

# With Channel(T)
channel = Channel(ClickedEvent).new

# With an aliased type
channel = ClickedEvent::Channel.new

my.on ClickedEvent, channel
```

When `on` is invoked with a channel, it implicitly creates and
adds an event handler which forwards received events into the channel.

#### Event handler options

All of the above methods for adding handlers support arguments `once`, `async`, and `at`.

`once` specifies whether the handler should run only once and then be automatically removed.
Default is false. In the future this option may be replaced with `times` which specifies
how many times to run before being removed.

As a convenience for adding handlers that should run only once, there is a method
named `once` available instead of the usual `on`. These two calls are equivalent:

```crystal
my.on ClickedEvent, handler, once: true, async: true, at: -1

my.once ClickedEvent, handler, async: true, at: -1
```

`async` specifies whether a handler should run synchronously or asynchronously. If
no specific value is provided, global default from `EventHandler.async` is used.
Default (`EventHandler.async?`) is false. You can either modify this default,
or specify `async` on a per-`on` basis.

`at` specifies the index in the list of handlers where new handler should be inserted.
While it is possible to specify the exact position, usually this value is
`0` (`EventHandler.at_beginning`) to insert at the beginning or `-1` (`EventHandler.at_end`)
to insert at the end of list. Default is `EventHandler.at_end`.

### Emitting events

Events can be emitted using `emit` in one of three ways:

By listing the event class and arguments one after another:

```crystal
my.emit ClickedEvent, 10, 20
```

By listing the event class and event instance one after another:

```crystal
my.emit ClickedEvent, ClickedEvent.new 10, 20
```

By creating an event instance and providing it as the single argument:

```crystal
my.emit ClickedEvent.new 10, 20
```

The handler methods will always receive one argument - the event object
with packed arguments. The return value from `emit` is that object.

### Handling events

As mentioned, handlers always receive one argument - the event object with packed arguments.

When an event is emitted using any of the available variants, such as:

```crystal
my.emit ClickedEvent, x: 10, y: 20
```

The arguments are directly accessible as getters on the event object:

```
my.on ClickedEvent do |e|
  puts "Clicked on position x=#{e.x}, y=#{e.y}"
end
```

### Return values

All handlers are defined with Nil as their return type and their return
value is ignored.

```crystal
my.on ClickedEvent do |e|
  p "Hello"
end
```

If event handlers should produce a return value, the recommended way
is to subclass Event into one that contains a return value, which
the handlers will update:

```crystal
require "event_handler"

class EventWithRetval < ::EventHandler::Event
  property return_value : Int32 = 0
end

class_record ClickedEvent < EventWithRetval, x : Int32, y : Int32

class MyClass
  include ::EventHandler
end
c = MyClass.new

c.on(ClickedEvent) { |e| e.return_value += e.x + e.y }

event = c.emit ClickedEvent, 1,2
p event.return_value #=> 3

c.emit ClickedEvent, event
p event.return_value #=> 6

c.emit event
p event.return_value #=> 9
```

Please note the above example will work correctly as long as event handlers are
invoked synchronously. Running one or more handlers asynchronously and checking
for the return value after all handlers have finished execution is currently not
addressed as part of built-in functionality.

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
  p "Hello"
end

my.on ClickedEvent, handler
my.off ClickedEvent, handler
```

By handler hash:

```crystal
handler = ClickedEvent::Handler.new do |e|
  p "Hello"
end

hash = handler.hash

my.on ClickedEvent, handler
my.off ClickedEvent, hash
```

By handler wrapper object:

```crystal
handler = ClickedEvent::Handler.new {
  p "Hello"
}

wrapper = my.on ClickedEvent, handler
my.off ClickedEvent, wrapper
```

Internally, handlers are always removed from events by removing their wrapper
object.

When wrappers are created implicitly by `on`, each invocation of `on`
gives handler a new wrapper object even if the same handler is added multiple
times for the same event. A call to
`off()` will find the first instance of this handler, then remove all
instances of its wrapper from the list (there will be only one), and then
invoke `RemoveHandlerEvent` with that instance as argument.
If a handler is added to an event more than once, it will be necessary to call
`off()` multiple times to remove all instances.

When handlers are added by using their wrappers directly, multiple identical
wrapper objects will be present in the list.
When `off()` is used to remove such handlers, all instances of their wrapper
will be removed from the list (there will be more than one) and `RemoveHandlerEvent`
will be invoked with the last removed instance as argument.

Whether `off(Event, handler | hash)` should be removing handlers by
wrapper (like it does now) or by handler, and whether `off()` should remove
all instances (like it does now) or at most one, is still being considered.

By handler index in the `handlers` Array:

```crystal
my.off ClickedEvent, at: 0
```

By removing all handlers at once:

```crystal
# With off
my.off ClickedEvent

# With remove_all_handlers
my.remove_all_handlers ClickedEvent
```

When all handlers are removed at once, `RemoveHandlerEvent`s will be emitted as
expected, and any multiple identical wrappers will be removed according to the
above-documented behavior.
If emitting `RemoveHandlerEvent` events should be disabled when removing all handlers,
provide argument *emit* to `off` or `remove_all_handlers`, or use
`EventHandler.emit_on_remove_all?` and `EventHandler.emit_on_remove_all=`
to change the default behavior.

### Meta Events

There are three built-in events:

`AddHandlerEvent` - Event emitted after a handler is added for any event, including itself.

`RemoveHandlerEvent` - Event emitted after a handler is removed from any event, including itself.

`AnyEvent` - Event emitted on any event. Adding a handler for this event allows listening for all emitted events and their arguments.

As mentioned, a wrapper object is implicitly created around a handler on every `on`, to encapsulate the handler and its
subscription options (the values of `once?`, `async?`, and `at`).
When `AddHandlerEvent` or `RemoveHandlerEvent` are emitted, they are invoked with the
handlers' `Wrapper` object as argument.
This allows listeners on these two meta events full insight into the added or removed handlers and their subscription data.

### Channels

Emitted events can also be sent through Channels. EventHandler comes with
convenience types and functions for this purpose:

Channels can be created with Channel(T) or an aliased type:

```crystal
# With Channel(T)
channel = Channel(ClickedEvent).new

# With an aliased type
channel = ClickedEvent::Channel.new
```

Invoking `on` with a Channel argument will implicitly create a handler that
forwards emitted events to the Channel:

```crystal
my.on ClickedEvent, channel, async: true
```

The same behavior can also be implemented manually:

```crystal
channel = Channel(ClickedEvent).new

my.on ClickedEvent, async: true do |e|
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
my.once ClickedEvent, async: true do |e|
  channel.send e
end
my.emit(ClickedEvent, 1,2)
p channel.receive
```

### Waiting for events

Using Channels, it is also possible to wait for events.

The above example already shows blocking on `channel.receive`.
The same effect can be achieved using convenience method `wait` and
avoiding visible use of Channels:

```crystal
e = my.wait(ClickedEvent)
```

`wait` can also be invoked with code. The accepted syntax and
arguments are the same as for `once`:

```crystal
# With a block
my.wait ClickedEvent do |e|
  p "Hello"
end

# With a Proc
handler = ClickedEvent::Handler.new do |e|
  p "Hello"
end
my.wait ClickedEvent, handler

# With a method
def on_clicked(e : ClickedEvent) : Nil
  p "Hello"
end
my.wait(ClickedEvent, ->on_clicked(ClickedEvent))
```

When waiting for events with code, two handlers are involved:

The first, visible one is the handler provided to
`wait`, containing code to execute once the event arrives.
`wait` argument *async* controls whether this handler will
run synchronously or asynchronously after the event has been
waited. This is consistent with the usual behavior and the
default value is `false` (`EventHandler.async?`).

The other, implicit one is the handler automatically created
and added to the list of event handlers. Once the event is
emitted and this handler runs, it will forward the received
event into the Channel.
`wait` argument *async_send* controls whether the event emitter
will block on `channel.send` or it will execute it in
a new fiber. The default value is `false` (`EventHandler.async_send?`).

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
    on(ClickedEvent)       {|e| p e }
    on(DoubleClickedEvent) {|e| p e }
    on(TripleClickedEvent) {|e| p e }
  end
end

my = My.new
my.emit ClickedEvent, 1, 2
my.emit DoubleClickedEvent, 3, 4
my.emit TripleClickedEvent, 5, 6
my.emit TripleClickedEvent, 7, 8, 9
```

Here is an example of an Event subclass that counts the number of times
the event was instantiated:

```crystal
require "event_handler"

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

class My; include EventHandler end
my = My.new

4.times { my.emit ClickedEvent, 1, 2 }

p ClickedEvent.count #=> 4
```

## API documentation

Run `crystal docs` as usual, then open file `docs/index.html`.

Also, see examples in the directory `examples/`.

## Testing

Run `crystal spec` as usual.

Also, see examples in the directory `examples/`.

## Thanks

* All the fine folks on Libera.Chat IRC channel #crystal-lang and on Crystal's Gitter channel https://gitter.im/crystal-lang/crystal

* Blacksmoke16 for a workable event model design

* Asterite, Absolutejam, and Tenebrousedge for additional discussion

## Other projects

List of interesting or similar projects in no particular order:

- https://github.com/Papierkorb/cute - Event-centric pub/sub model for objects inspired by the Qt framework

- https://github.com/hugoabonizio/event_emitter.cr - Idiomatic asynchronous event-driven architecture

- https://github.com/vladfaust/callbacks.cr - Expressive callbacks module for Crystal

- https://github.com/anykeyh/await_async - Provide await and async methods to Crystal

- https://github.com/firejox/CrSignals - Signals/slots notification library in Crystal

- https://github.com/crystal-community/future.cr - Provides delay, future, and lazy convenient methods

## Licensing

For licensing to use in your next project, consider
https://perens.com/2020/10/06/post-open-source-license-early-draft/ and https://licenseuse.org/.
