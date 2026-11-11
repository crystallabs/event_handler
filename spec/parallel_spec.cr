require "./spec_helper"
require "wait_group"

EventHandler.event ParallelTick, n : Int32

class ParallelEmitter
  include EventHandler
end

# Fibers run in parallel on several threads; the emitter's lock-free `emit`
# must hold up against `on`/`off`/`once` running on other threads.
{% if Fiber.has_constant?(:ExecutionContext) %}
  describe "EventHandler across threads" do
    it "runs every once-handler exactly once while subscribing and emitting in parallel" do
      ctx = Fiber::ExecutionContext::Parallel.new("event_handler-spec", 4)
      e = ParallelEmitter.new
      once_calls = Atomic(Int32).new(0)
      stop = Atomic(Bool).new(false)
      per_writer = 2_000

      emitters = WaitGroup.new
      2.times do
        emitters.add
        ctx.spawn do
          until stop.get
            e.emit ParallelTick, 1
            Fiber.yield
          end
          emitters.done
        end
      end

      writers = WaitGroup.new
      2.times do
        writers.add
        ctx.spawn do
          per_writer.times do
            sub = e.on(ParallelTick) { }
            e.once(ParallelTick) { once_calls.add 1 }
            sub.off
          end
          writers.done
        end
      end

      writers.wait
      e.emit ParallelTick, 1
      stop.set true
      emitters.wait

      once_calls.get.should eq 2 * per_writer
      e.handlers(ParallelTick).size.should eq 0
      e.has_handlers?(ParallelTick).should be_false
    end
  end
{% end %}
