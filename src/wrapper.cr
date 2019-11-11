module EventHandler
  # Generic class wrapping each installed handler.
  #
  # It is generally not used directly; but is exposed by the system in response to `on()`
  # and is sent as an argument to `AnyEvent`, `AddHandlerEvent`, and `RemoveHandlerEvent`.
  #
  # It provides additional information about the handler, such as values for
  # *once*, *async*, and initial position/index in the list of event's handlers.
  #
  # The information about the index is informational. The best use is to check it for
  # values of 0 or -1, indicating that handler was added at the beginning or end of
  # list respectively.
  class Wrapper(T)
    getter  handler : T
    getter  handler_hash : UInt64
    getter? once : Bool
    getter? async : Bool
    getter  at : Int32
    def initialize(@handler : T, @once, @async, @at, hash = nil)
      @handler_hash = hash || @handler.hash
    end
    def call(obj, async)
      async = @async if async.nil?
      if async
        spawn do @handler.call obj end
        nil
      else
        @handler.call obj
      end
    end
  end
end
