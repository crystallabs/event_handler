require "log"

module EventHandler
  # Logger used to report failures that occur while dispatching a handler
  # asynchronously. See `Wrapper#call_async` for the async error contract.
  #
  # Per Crystal's `Log` conventions, emits nothing until the application
  # configures a backend (e.g. `Log.setup_from_env`). Applications that care
  # about async handler failures should configure one to see these entries.
  Log = ::Log.for("event_handler")

  # Generic class wrapping each installed handler.
  #
  # Not generally used directly; implicitly created and returned by `on()`, and
  # sent as an argument to emitted `AddHandlerEvent`/`RemoveHandlerEvent` events.
  #
  # Holds each handler's *once*, *async*, and *at* (initial insertion position
  # in the handler list) settings. *at* is informational — mainly useful to
  # check for 0 or -1, meaning insertion at the beginning or end of the list.
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
    # Handlers are `Proc(T, Nil)`, so their own return conveys nothing;
    # returning the dispatched event instead lets `wait(type, handler)`/
    # `wait(type) { ... }` yield it, matching the handler-less `wait` overloads.
    # The async branch also returns *obj* even though the handler runs in its
    # own fiber. `_emit` ignores this return value, so dispatch is unaffected.
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
    # closure on entry to whatever method contains the block. Keeping it in its
    # own method confines that allocation to the async path, leaving
    # synchronous dispatch allocation-free.
    #
    # Async error contract:
    #
    # In the synchronous path (`#call` without async), a handler that raises
    # propagates straight to the caller of `emit`/`call`, unchanged by this
    # method.
    #
    # In the async path the handler runs in its own detached fiber, so a raised
    # exception has no caller to propagate to. Crystal's default for an
    # unhandled exception in a spawned fiber is to abort the whole process; a
    # bare `spawn` with no rescue also loses the failure silently. To avoid
    # both, the fiber rescues any exception and logs it via `EventHandler::Log`
    # at `error` level, so it's observable without aborting the process or
    # disturbing other handlers' fibers.
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
