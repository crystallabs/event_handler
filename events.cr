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

# Now, we can actually emit the event 'ClickedEvent' with some coordinates x and y.
# In turn this will activate all three handlers we have installed.
# Since there are two ways how we can emit() an event, 2 x 3 will result in total 6 lines printed to screen:

# Option 1, with event, and arguments just listed one after another:
c.emit ClickedEvent, 1, 2

# Option 2, with event, and arguments packed into the event:
c.emit ClickedEvent, ClickedEvent.new 3, 4

# In addition to this, there are some "special" events, namely NewListenerEvent, RemoveListenerEvent, and EventEvent.
# The first run whenever any listener is added on object; the second when any is removed.
# (The third (EventEvent) should be emitted when any event is emitted, but currently it is not functioning.)

# So, to listen for removals of listeners, we would do it like this:
c.on(::Crysterm::RemoveListenerEvent){|e| p "Handler #{e.handler} was just removed for event #{e.event}!"; true}

# To listen for additions of listeners, we would do it like this (This will trigger even for our own adding ourselves):
c.on(::Crysterm::NewListenerEvent){|e| p "Handler #{e.handler} was just added for event #{e.event}!"; true}

# And when we remove a handler, this will trigger the RemoveListenerEvent listener:
c.off(ClickedEvent, handler)
