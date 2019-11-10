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

  ## Mouse
  #event MouseOverEvent
  #event MouseOutEvent
  #event MouseDownEvent
  #event MouseUpEvent
  #event WheelDownEvent
  #event WheelUpEvent

  ## Gpm-specific
  #event MouseMoveEvent,        data : GpmEvent
  #event MouseDragEvent,        data : GpmEvent
  #event MouseWheelEvent,       data : GpmEvent
  #event MouseButtonDownEvent,  data : GpmEvent
  #event MouseDoubleClickEvent, data : GpmEvent
  #event MouseButtonUpEvent,    data : GpmEvent
  #event MouseClickEvent,       data : GpmEvent

  event GpmEvent,
    buttons : UInt8,
    modifiers : UInt8,
    vc : UInt16,
    dx : Int16,
    dy : Int16,
    x : Int16,
    y : Int16,
    type : Int32,
    clicks : Int32,
    margin : Int32,
    wdx : Int16,
    wdy : Int16
  class GpmEvent < Event
    def button
      if (@buttons & 4)> 0; return :left   end
      if (@buttons & 2)> 0; return :middle end
      if (@buttons & 1)> 0; return :right  end
      nil
    end
    def shift?() (@modifiers & 1)> 0 ? true : false end
    def ctrl?()  (@modifiers & 4)> 0 ? true : false end
    def meta?()  (@modifiers & 8)> 0 ? true : false end
  end

  event MouseEvent,
    action : Symbol,
    button : Symbol?,
    x : Int16,
    y : Int16,
    dx : Int16,
    dy : Int16,
    wdx : Int16,
    wdy : Int16,
    shift : Bool,
    meta : Bool,
    ctrl : Bool,
    raw : GpmEvent,
    type : Symbol
  class MouseEvent < Event
    delegate :button, :shift?, :ctrl?, :meta?, to: @raw
  end

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
