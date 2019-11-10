require "../src/events"

# The above include file defines the most basic events required for the system to work.

# Let's define an additional event that we need. Let's say it represents a mouse click and gives us the x and y values of the click:
event ClickedEvent, x : Int32, y : Int32

# After we have defined any/all new events we need, we can include the event emitter and cause macros for all events to run:
require "../src/event_emitter"

# Now let's create an example class and make it event-enabled:
class MyClass
	include ::Crysterm::EventEmitter
end
c = MyClass.new

# Now there are three ways to register a handler that will run on a certain event:
# (In all cases, the handler function always receives just one argument which is the event object, and all arguments can be read from it.)

# Method 1, via block:

c.on(ClickedEvent) { |e| p "Handler for event 'ClickedEvent', variant 1. Coordinates are x=#{e.x} y=#{e.y}"; true }

# Method 2, via Proc and repeating the arguments:

handler = ->(e : ClickedEvent) { p "Handler for event 'ClickedEvent', variant 2. Coordinates are x=#{e.x} y=#{e.y}"; true }
c.on ClickedEvent, handler

# Method 3, via prepared handler:

handler = ClickedEvent::Handler.new { |e| p "Handler for event 'ClickedEvent', variant 3. Coordinates are x=#{e.x} y=#{e.y}"; true }
c.on ClickedEvent, handler

# Additional options:

# Now, additionally, each of the above three variants of calling on() supports specifying whether the handler
# should default to run asynchronously or not, and whether it should run always or only once and then be
# automatically removed. The defaults are to run with async=false and once=false.
# So, for example, we can add the above-created handler again, this time with async at once options:

c.on ClickedEvent, handler, async: true, once: true

# In addition to this, there are some "special" events, namely AddHandlerEvent, RemoveHandlerEvent, and AnyEvent.
# AddHandlerEvent runs whenever any handler is added on event; RemoveHandlerEvent runs when it is removed, including
# when it was automatically removed due to having option 'once: true'.
# And AnyEvent is emitted when any other event is emitted.

# To listen for additions of handlers, we would do it like this (This will trigger even for our own adding ourselves):
c.on(::Crysterm::AddHandlerEvent){|e| p "Handler #{e.handler} was just added for event #{e.event}!"; true}

# To listen for removals of handlers, we would do it like this. This will now trigger as soon as we emit the
# previously defined ClickedEvent, because the last event we added had 'once: true'.
c.on(::Crysterm::RemoveHandlerEvent){|e| p "Handler #{e.handler} was just removed for event #{e.event}!"; true}

# And we can also add a handler for AnyEvent:
c.on(::Crysterm::AnyEvent) { |e| p "Listening for all events, and noticed event #{e.class} emitted"; true }

# Now, we can actually emit the event 'ClickedEvent' with some coordinates x and y.
# In turn this will activate 6 events: 2 event handlers we added for ClickedEvent, 2 for NewHandlerEvent,
# 1 for AnyEvent, and 1 for RemoveHandlerEvent when 'once: true' kicks in an automatically removes one handler.

# We can emit an event in 2 ways:

# Option 1, with event, and arguments just listed one after another:
c.emit ClickedEvent, 1, 2

# Option 2, with event, and arguments packed into the event:
c.emit ClickedEvent, ClickedEvent.new 3, 4

# And when we remove a handler, this will trigger the RemoveHandlerEvent handler:
c.off(ClickedEvent, handler)

# Remove all handlers currently registered for ClickedEvent
c.remove_all_handlers(ClickedEvent)

# Add a handler for ExceptionEvent, and see that it will receive the emitted exception
c.on(::Crysterm::ExceptionEvent) { |e| p "Running exception handler: #{e.exception.to_s}"; true }
c.emit(::Crysterm::ExceptionEvent, Exception.new "Example of a handled exception; it won't raise")

# Remove the handlers for ExceptionEvent, and see that the unhandled ExceptionEvent will be raised
c.remove_all_handlers(::Crysterm::ExceptionEvent)
c.emit(::Crysterm::ExceptionEvent, Exception.new "Example of an unhandled exception; it will raise (NOT A BUG, IT IS AN EXAMPLE)")
