require "./macros"

module Crysterm

  # This file lists non-core events, i.e. all events used above EventEmitter.
  # This means events from `Node` and all its further subclasses.
  # Core events are in `src/events.cr`.

  event ReparentEvent
  event AdoptEvent,    element : ::Crysterm::Widgets::Node
  event AttachEvent
  event DetachEvent
  event RemoveEvent,   element : ::Crysterm::Widgets::Node
  event DestroyEvent

  event ResizeEvent
  event FocusEvent
  event BlurEvent
  event WarningEvent,  text : String

end
