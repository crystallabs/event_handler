# Per-emitter footprint of the handler store, with a large event population.
#
# Every emitter (`include EventHandler`) used to carry one eagerly allocated
# `Array` instance variable per `Event` subclass in the program. With a few
# hundred event types (a TUI with one event class per key is the motivating
# case) that was ~2 KB of pointers per object, a few hundred retained empty
# arrays, and as many allocations at construction and locks at teardown.
# The store is now a per-emitter bitmask plus a map created on first `on`.
#
# This benchmark defines 240 event classes, then measures what one emitter
# costs: its `instance_sizeof`, the heap it allocates when constructed, the
# `emit` cost with and without a listener, and whole-object
# `remove_all_handlers`.
#
# Run:  crystal run --release benchmarks/emitter-footprint.cr
#
# Reference (Apple M-series, Crystal 1.21), eager per-type arrays vs. the
# lazy store:
#
#   instance_sizeof              1968 B  ->    56 B
#   heap per constructed emitter 9.9 KB  ->   148 B
#   emit, no listener             ~5 ns  ->  ~1 ns
#   emit, one listener           ~18 ns  -> ~16 ns   (now one map lookup; noise-level)
#   remove_all_handlers         ~4.0 us  -> ~15 ns

require "../src/event_handler"

{% for i in 0...240 %}
  class Ev{{ i }} < ::EventHandler::Event
    def initialize
    end
  end
{% end %}

class Click < ::EventHandler::Event
  getter x : Int32

  def initialize(@x)
  end
end

class Emitter
  include EventHandler
end

N = 20_000

def heap_kb(&)
  GC.collect
  before = GC.stats.total_bytes
  yield
  (GC.stats.total_bytes - before) / 1024.0
end

def ns_per(rounds, &) : Float64
  best = Float64::INFINITY
  3.times do
    el = Time.measure { rounds.times { yield } }
    ns = el.total_nanoseconds / rounds
    best = ns if ns < best
  end
  best
end

event_types = {{ ::EventHandler::Event.all_subclasses.size }}
puts "event types:              #{event_types}"
puts "instance_sizeof(Emitter): #{instance_sizeof(Emitter)} B"

emitters = [] of Emitter
kb = heap_kb { N.times { emitters << Emitter.new } }
puts "heap per constructed emitter: #{(kb * 1024 / N).round(1)} B (#{kb.round(1)} KiB for #{N})"

# One listener on another type, so the emitter is not entirely empty.
emitters.each &.on(Click) { }
kb = heap_kb { emitters.each &.emit(Ev7) }
puts "garbage per no-listener emit: #{(kb * 1024 / N).round(2)} B"
ns = ns_per(50) { emitters.each &.emit(Ev7) } / N
puts "emit, no listener:  #{ns.round(2)} ns"

sum = 0
emitters.each &.on(Click) { |e| sum += e.x }
ns = ns_per(50) { emitters.each &.emit(Click, 1) } / N
puts "emit, one listener: #{ns.round(2)} ns (checksum #{sum})"

el = Time.measure { emitters.each &.remove_all_handlers }
puts "remove_all_handlers: #{(el.total_nanoseconds / N).round(1)} ns per emitter"
