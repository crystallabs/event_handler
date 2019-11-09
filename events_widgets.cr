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
  event WarningEvent,  text : String

  # Mouse
  event MouseEvent,    x : Int32, y : Int32
  event ClickEvent
  event MouseOverEvent
  event MouseOutEvent
  event MouseDownEvent
  event MouseUpEvent
  event MouseWheelEvent
  event WheelDownEvent
  event WheelUpEvent
  event MouseMoveEvent
  event GpmDataEvent,  data : Bytes

  event UncaughtExceptionEvent, exception : Exception
  event SigTermEvent
  event SigIntEvent
  event SigQuitEvent
  event ExitEvent

  event BlurEvent, element : ::Crysterm::Widgets::Node?
  event FocusEvent, element : ::Crysterm::Widgets::Node?

  event PreRenderEvent
  event RenderEvent

  alias Key = NamedTuple(sequence: String, name: String?, code: String?, ctrl: Bool, meta: Bool, shift: Bool)

  event KeypressEvent, ch : String?, key : Key?

end
