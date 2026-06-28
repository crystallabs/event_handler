require "log"

module EventHandler
  # Logger used to report failures that occur while dispatching a handler
  # asynchronously. See `Wrapper#call_async` for the async error contract.
  #
  # Following Crystal's `Log` conventions, this emits nothing until the
  # application configures a backend (e.g. `Log.setup_from_env` or
  # `::Log.setup(:warning)`). Applications that care about async handler
  # failures should configure a backend so these `error`-level entries
  # become visible.
  Log = ::Log.for("event_handler")

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
    getter handler : T
    getter handler_hash : UInt64
    getter? once : Bool
    getter? async : Bool
    getter at : Int32

    def initialize(@handler : T, @once = false, @async = ::EventHandler.async?, @at = ::EventHandler.at_end, hash = nil)
      @handler_hash = hash || @handler.hash
    end

    def initialize(once = false, async = ::EventHandler.async?, at = ::EventHandler.at_end, hash = nil, &handler : T)
      initialize handler, once, async, at, hash
    end

    # Dispatches *obj* to the wrapped handler and returns *obj*.
    #
    # The handler itself always returns `Nil` (handlers are `Proc(T, Nil)`),
    # so returning that result conveys nothing. Returning the dispatched event
    # instead is what makes `wait(type, handler)`/`wait(type) { ... }` yield the
    # emitted event, matching the handler-less `wait` overloads (which already
    # return it). The async branch likewise returns *obj* — the handler runs in
    # its own fiber, but the caller still gets the event back. `_emit` ignores
    # this return value, so the dispatch path is unaffected.
    def call(obj, async = nil)
      async = @async if async.nil?
      if async
        call_async obj
      else
        @handler.call obj
      end
      obj
    end

    # The `spawn` block closes over *obj*, and Crystal heap-allocates that
    # closure environment on entry to whatever method contains the block —
    # which, if the `spawn` lived directly in `#call`, would mean an allocation
    # on *every* call, including the (common) synchronous path that never spawns.
    # Keeping the closure in its own method confines that allocation to the
    # async path, leaving synchronous dispatch allocation-free.
    #
    # Async error contract:
    #
    # In the synchronous path (`#call` without async), a handler that raises
    # propagates the exception straight to the caller of `emit`/`call`, exactly
    # as before — this method does NOT alter that behavior.
    #
    # In the asynchronous path the handler runs in its own `spawn`ed fiber,
    # detached from the emitter, so a raised exception has no caller to
    # propagate to. Crystal's default for an unhandled exception in a spawned
    # fiber is to abort the whole *process*, which would let a single
    # misbehaving async handler take down an otherwise healthy application; a
    # bare `spawn` with no rescue also makes the failure easy to lose. To avoid
    # both silent loss and process abort, the fiber rescues any exception and
    # routes it through `EventHandler::Log` at `error` level (message +
    # exception). The failure is therefore observable and contained: it neither
    # vanishes without a trace nor disturbs unrelated state or other handlers,
    # which keep running independently in their own fibers.
    private def call_async(obj)
      spawn do
        begin
          @handler.call obj
        rescue ex
          Log.error(exception: ex) { "Unhandled exception in async event handler" }
        end
      end
    end
  end
end
