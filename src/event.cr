module EventHandler
  # Basic event class; all events must inherit from `Event`.
  #
  # This abstract class is generally not used directly; see macro `event`.
  #
  # To extend the class produced by `event` if needed, either reopen the class
  # after defining it with `event`:
  #
  # ```
  # event ClickedEvent, x : Int32, y : Int32
  #
  # class ClickedEvent < ::EventHandler::Event
  #   property test : String
  # end
  # ```
  #
  # or create the whole class manually:
  #
  # ```
  # class ClickedEvent < ::EventHandler::Event
  #   getter x : Int32
  #   getter y : Int32
  #   property test : String
  #
  #   def initialize(@x, @y)
  #   end
  # end
  # ```
  abstract class Event
    macro inherited
      macro finished
        alias Handler = ::Proc(\{{@type}}, Nil)
        alias Wrapper = ::EventHandler::Wrapper(Handler)
        alias Channel = ::Channel(self)
      end
    end
  end
end
