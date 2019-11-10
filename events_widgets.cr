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
  event MouseOverEvent
  event MouseOutEvent
  event MouseDownEvent
  event MouseUpEvent
  event WheelDownEvent
  event WheelUpEvent

  # Gpm-specific
  event MouseMoveEvent,        data : GpmData
  event MouseDragEvent,        data : GpmData
  event MouseWheelEvent,       data : GpmData
  event MouseButtonDownEvent,  data : GpmData
  event MouseDoubleClickEvent, data : GpmData
  event MouseButtonUpEvent,    data : GpmData
  event MouseClickEvent,       data : GpmData
  record GpmData,
    buttons : Int8,
    modifiers : Int8,
    vc : UInt16,
    dx : Int16,
    dy : Int16,
    x : Int16,
    y : Int16,
    type : Int16,
    clicks : Int32,
    margin : Int32,
    wdx : Int16,
    wdy : Int16
  event GpmDataEvent,  data : GpmData
  #class GpmExceptionEvent < ExceptionEvent; end

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
