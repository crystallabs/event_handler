require "./spec_helper"
require "log/spec"

EventHandler.event AsyncBoomEvent, val : Int32

module EventHandler
  class AsyncErrorTest
    include ::EventHandler
  end

  describe "async handler error contract" do
    # An async handler that raises must NOT silently vanish and must NOT
    # prevent unrelated handlers from running: the exception is rescued inside
    # the spawned fiber and surfaced through `EventHandler::Log` at `error`
    # level, while other async handlers run independently.
    it "logs the exception and still runs other handlers" do
      c = AsyncErrorTest.new

      # Buffered so the producing fiber never blocks even if we time out;
      # this keeps the spec from being able to hang.
      ran = ::Channel(Bool).new(1)

      c.on AsyncBoomEvent, async: true do |_e|
        raise "boom"
      end
      c.on AsyncBoomEvent, async: true do |_e|
        ran.send true
      end

      ::Log.capture("event_handler") do |logs|
        c.emit AsyncBoomEvent, 1

        # Wait (bounded) for the second async handler to run, proving the
        # raising handler did not abort the process or block its siblings.
        select
        when ran.receive
          # ok
        when timeout(2.seconds)
          raise "second async handler did not run within timeout"
        end

        # The raising handler's fiber is enqueued before the sender's, so by the
        # time we receive above it has already logged.
        logs.check(:error, /async event handler/)
      end
    end
  end
end
