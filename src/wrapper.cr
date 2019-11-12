module EventHandler
  # Generic class wrapping each installed handler.
  #
  # This class is generally not used directly, but is implicitly created and returned in response to `on()`.
  #
  # It is also sent as an argument to emitted `AddHandlerEvent` and `RemoveHandlerEvent` events.
  #
  # It holds settings associated with each installed handler; its values for
  # *once*, *async*, and *at* (the initial insertion position in the list of handlers).
  #
  # *at* value is informational. Probably best use is to check for
  # values of 0 or -1, indicating the handler's insertion at the beginning or end of
  # list respectively.
  class Wrapper(T)
    getter  handler : T
    getter  handler_hash : UInt64
    getter? once : Bool
    getter? async : Bool
    getter  at : Int32

    def initialize(@handler : T, @once = false, @async = ::EventHandler.async?, @at = ::EventHandler.at_end, hash = nil)
      @handler_hash = hash || @handler.hash
    end

    def initialize(once = false, async = ::EventHandler.async?, at = ::EventHandler.at_end, hash = nil, &handler : T)
      initialize handler, once, async, at, hash
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
