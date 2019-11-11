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

## Usage

Here's a basic example that defines two events, installs a handler for each event, emits the events, and removes the event handlers:

```crystal
require "../src/event_handler"

# Define event:
event TestEvent, message : String, status : Bool

# Create a class and instantiate it:
class MyClass
  include EventHandler
  event ClickedEvent, x : Int32, y : Int32
end
my = MyClass.new

# Add handlers for the events:

# Add one handler as a block:
my.on(TestEvent) { |e|
  puts "Activated on #{e.class}. Message is '#{e.message}' and status is #{e.status}"
  true
}

# And one as a proc:
handler = ->(e : MyClass::ClickedEvent) {
  puts "Clicked on position x=#{e.x}, y=#{e.y}"
  true
}
my.on MyClass::ClickedEvent, handler

# Emit events:
my.emit TestEvent, "Hello, World!", true
my.emit MyClass::ClickedEvent, 10, 20

# Remove handlers:
my.remove_all_handlers TestEvent
my.off MyClass::ClickedEvent, handler
```

## Documentation

Run `crystal docs` as usual, then open file `docs/index.html`.

## Testing

Run `crystal spec` as usual.

## Thanks

* All the fine folks on FreeNode IRC channel #crystal-lang and on Crystal's Gitter channel https://gitter.im/crystal-lang/crystal

* Blacksmoke16 for a workable event model design

* Asterite, Absolutejam, and Tenebrousedge for additional discussion

## Related projects

List of interesting or related projects in no particular order:

- https://github.com/hugoabonizio/event_emitter.cr - Idiomatic asynchronous event-driven architecture
