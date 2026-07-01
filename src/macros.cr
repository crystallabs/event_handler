# Creates class *name* in a single line, like the standard `record` macro for structs.
#
# Unlike `record`, `class_record` creates classes. Properties are exposed as
# getters only, not getters+setters (may change in the future).
#
# Adapted from Crystal's 0.31.1 `record` macro.
#
# ```
# class_record MyClass, a : ::Int32, b : String, c : ::Bool
# ```
macro class_record(name, *properties)
  class {{name.id}}
    {% for property in properties %}
      {% if property.is_a?(Assign) %}
        getter {{property.target.id}}
      {% elsif property.is_a?(TypeDeclaration) %}
        getter {{property.var}} : {{property.type}}
      {% else %}
        getter :{{property.id}}
      {% end %}
    {% end %}

    def initialize({{
                     properties.map do |field|
                       "@#{field.id}".id
                     end.splat
                   }})
    end

    {{yield}}

    def copy_with({{
                    properties.map do |property|
                      if property.is_a?(Assign)
                        "#{property.target.id} _#{property.target.id} = @#{property.target.id}".id
                      elsif property.is_a?(TypeDeclaration)
                        "#{property.var.id} _#{property.var.id} = @#{property.var.id}".id
                      else
                        "#{property.id} _#{property.id} = @#{property.id}".id
                      end
                    end.splat
                  }})
      self.class.new({{
                       properties.map do |property|
                         if property.is_a?(Assign)
                           "_#{property.target.id}".id
                         elsif property.is_a?(TypeDeclaration)
                           "_#{property.var.id}".id
                         else
                           "_#{property.id}".id
                         end
                       end.splat
                     }})
    end

    def clone
      self.class.new({{
                       properties.map do |property|
                         if property.is_a?(Assign)
                           "@#{property.target.id}.clone".id
                         elsif property.is_a?(TypeDeclaration)
                           "@#{property.var.id}.clone".id
                         else
                           "@#{property.id}.clone".id
                         end
                       end.splat
                     }})
    end
  end
end

module EventHandler
  # Creates events in a single line; every event is a class inheriting from `EventHandler::Event`.
  #
  # Since events are classes, they can also be created manually.
  # See `EventHandler::Event` for more details.
  #
  # ```
  # event MouseClick, x : ::Int32, y : ::Int32
  # ```
  macro event(e, *args)
    class_record {{e.id}} < ::EventHandler::Event{% if args.size > 0 %}, {{ args.splat }}{% end %}
  end

  # :nodoc:
  # EventHandler macro magic
  macro finished
    \{% begin %}
      \{% for e in ::EventHandler::Event.all_subclasses %}
        \{% handlers_list = "_event_" + e.name.identify.underscore.tr("()", "__").stringify %}
        \{% event_class = e.name.split('(').first.id %}

        # Handlers-list getter names for the three meta-event classes. Unlike
        # `handlers_list`, these don't depend on `e`, so they're computed once
        # here rather than recomputed inline at every use site. Same
        # `name.identify.underscore.tr("()", "__")` transform as `handlers_list`,
        # so names match the generated getters.
        \{% add_handlers_list = "_event_" + ::EventHandler::AddHandlerEvent.name.identify.underscore.tr("()", "__").stringify %}
        \{% remove_handlers_list = "_event_" + ::EventHandler::RemoveHandlerEvent.name.identify.underscore.tr("()", "__").stringify %}
        \{% any_handlers_list = "_event_" + ::EventHandler::AnyEvent.name.identify.underscore.tr("()", "__").stringify %}

        private getter \{{handlers_list.id}} = ::Array(Wrapper(::Proc(\{{event_class}}, ::Nil))).new

        private def internal_insert(type : \{{event_class}}.class, wrapper : ::EventHandler::Wrapper(::Proc(::EventHandler::Event, ::Nil)))
          _event_handler_mutex.synchronize do
            \{% if ::EventHandler::EMIT_COPY_ON_WRITE %}
              # Publish a fresh array so any in-flight `_emit` keeps iterating
              # its captured snapshot. See `EMIT_COPY_ON_WRITE`.
              updated = \{{handlers_list.id}}.dup
              updated.insert wrapper.at, wrapper
              @\{{handlers_list.id}} = updated
            \{% else %}
              \{{handlers_list.id}}.insert wrapper.at, wrapper
            \{% end %}
          end

          # Only build+dispatch the `AddHandlerEvent` when something is listening
          # for it. `_emit AddHandlerEvent, ...` constructs a fresh
          # `AddHandlerEvent.new(...)` wrapper before `_emit` reaches its
          # empty-list fast path, so without this guard every `on()` would
          # allocate and immediately discard one. Same idea as the `AnyEvent`
          # guard in `emit`.
          \{% if ::EventHandler::EMIT_SKIP_WHEN_NO_HANDLERS %}
            unless \{{add_handlers_list.id}}.empty?
              _emit ::EventHandler::AddHandlerEvent, type, wrapper.unsafe_as(::EventHandler::Wrapper(::Proc(::EventHandler::Event, ::Nil)))
            end
          \{% else %}
            # Use this:
            _emit ::EventHandler::AddHandlerEvent, type, wrapper.unsafe_as(::EventHandler::Wrapper(::Proc(::EventHandler::Event, ::Nil)))

            # Or this:
            #handler2 = ::Proc(::EventHandler::Event,::Nil).new do |e| wrapper.handler.call e.as { {e.id}} end
            #wrapper2 = ::EventHandler::Wrapper(::Proc(::EventHandler::Event, ::Nil)).new handler2, wrapper.once?, wrapper.async?, wrapper.at
            #_emit ::EventHandler::AddHandlerEvent, type, wrapper2
          \{% end %}

          wrapper
        end
        private def internal_insert(type : \{{event_class}}.class, handler : ::Proc(\{{event_class}}, ::Nil), once : ::Bool, async : ::Bool, at : ::Int)
          internal_insert(type, wrapper(type, handler, once, async, at))
        end
        private def wrapper(type : \{{event_class}}.class, handler : ::Proc(\{{event_class}}, ::Nil), once : ::Bool, async : ::Bool, at : ::Int)
          ::EventHandler::Wrapper(::Proc(\{{event_class}}, ::Nil)).new handler, once, async, at
        end

        # Adds *handler* to the list of handlers for event *type*.
        def on(type : \{{event_class}}.class, handler : ::Proc(\{{event_class}}, ::Nil), once = false, async = ::EventHandler.async?, at = ::EventHandler.at_end)
          internal_insert type, handler, once, async, at
        end
        # :ditto:
        def on(type : \{{event_class}}.class, once = false, async = ::EventHandler.async?, at = ::EventHandler.at_end, &handler : \{{event_class}} -> ::Nil)
          on type, handler, once, async, at
        end
        # :ditto:
        def on(type : \{{event_class}}.class, wrapper : ::EventHandler::Wrapper(::Proc(::EventHandler::Event, ::Nil)))
          internal_insert type, wrapper
        end
        # Adds an autogenerated handler which sends emitted events to *channel*
        def on(type : \{{event_class}}.class, channel : ::Channel(\{{event_class}}), once = false, async = ::EventHandler.async?, at = ::EventHandler.at_end)
          on(type, once, async, at) { |e| channel.send e; true }
        end

        # Adds *handler* to the list of handlers for event *type*; removed
        # automatically after it triggers once.
        #
        # Equivalent to `on` with argument *once*.
        def once(type : \{{event_class}}.class, handler : ::Proc(\{{event_class}}, ::Nil), async = ::EventHandler.async?, at = ::EventHandler.at_end)
          on type, handler, true, async, at
        end
        # :ditto:
        def once(type : \{{event_class}}.class, async = ::EventHandler.async?, at = ::EventHandler.at_end, &handler : \{{event_class}} -> ::Nil)
          on type, handler, true, async, at
        end
        # Adds an autogenerated handler which sends emitted events to *channel*;
        # removed automatically after it triggers once.
        #
        # Equivalent to `on` with argument *once*.
        def once(type : \{{event_class}}.class, channel : ::Channel(\{{event_class}}), async = ::EventHandler.async?, at = ::EventHandler.at_end)
          on type, channel, true, async, at
        end

        # Blocks until event *type* is emitted and executes *handler*.
        #
        # *handler* may be `nil`, in which case `wait` blocks until the event
        # arrives and returns it without running any handler.
        def wait(type : \{{event_class}}.class, handler : ::Proc(\{{event_class}}, ::Nil)?, async = ::EventHandler.async?, at = ::EventHandler.at_end, async_send = ::EventHandler.async_send?)
          channel = ::Channel(\{{event_class}}).new
          once type, channel, async_send, at
          e = channel.receive
          # Guard against a nil *handler*: the parameter is explicitly typed as
          # nilable, but building (and calling) a `wrapper` from a nil proc is a
          # type error / nil dispatch. When no handler is given, just return the
          # received event, mirroring the handler-less `wait` overload.
          if handler
            wrapper(type, handler, true, async, at).call e
          else
            e
          end
        end
        # :ditto:
        def wait(type : \{{event_class}}.class, async = ::EventHandler.async?, at = ::EventHandler.at_end, async_send = ::EventHandler.async_send?, &handler : \{{event_class}} -> ::Nil)
          wait type, handler, async, at, async_send
        end
        # Blocks until event *type* is emitted and returns emitted event.
        def wait(type : \{{event_class}}.class, async_send = ::EventHandler.async_send?, at = ::EventHandler.at_end)
          channel = ::Channel(\{{event_class}}).new
          once type, channel, async_send, at
          channel.receive
        end

        # Emits the `RemoveHandlerEvent` announcing that *w* was removed from the
        # handlers for *type*. Always called outside the handler-list lock, so a
        # `RemoveHandlerEvent` handler may freely call back into `on`/`off`.
        private def emit_remove_handler_event(type : \{{event_class}}.class, w : ::EventHandler::Wrapper(::Proc(\{{event_class}}, ::Nil)))
          # Skip building the `RemoveHandlerEvent` wrapper when nobody listens for
          # it — `_emit` would otherwise allocate it before its empty-list fast
          # path. Mirrors the `AddHandlerEvent` guard in `internal_insert`.
          \{% if ::EventHandler::EMIT_SKIP_WHEN_NO_HANDLERS %}
            unless \{{remove_handlers_list.id}}.empty?
              _emit ::EventHandler::RemoveHandlerEvent, type, w.unsafe_as(::EventHandler::Wrapper(::Proc(::EventHandler::Event, ::Nil)))
            end
          \{% else %}
            _emit ::EventHandler::RemoveHandlerEvent, type, w.unsafe_as(::EventHandler::Wrapper(::Proc(::EventHandler::Event, ::Nil)))
          \{% end %}
        end

        # Outside-the-lock tail shared by the removal paths (`_off_first` and
        # `off(type, at)`): given the wrapper their locked removal pass produced
        # (or `nil` if nothing matched), announces its removal outside the
        # handler-list lock — so a `RemoveHandlerEvent` handler may freely call
        # back into `on`/`off` — and returns it. The two callers' synchronize
        # bodies can't merge (one finds-and-deletes a wrapper, the other deletes
        # by index), but this trailing announce-and-return was identical in
        # both, so it lives here once.
        private def _announce_removed(type : \{{event_class}}.class, w)
          if w
            emit_remove_handler_event type, w
            w
          end
        end

        # Shared core for the predicate-based `off` overloads below
        # (`off(handler)`, `off(hash)`, `off(wrapper)`), which differ only in how
        # they recognize the handler to drop. In a single locked pass it locates
        # the first wrapper for which the block returns true, removes every
        # identical copy from the list — in place, or by publishing a fresh
        # array under copy-on-write — and returns it; the matching
        # `RemoveHandlerEvent` is then emitted outside the lock (so its handler
        # may freely call back into `on`/`off`). Centralizes this
        # correctness-sensitive logic so the overloads can't drift apart.
        private def _off_first(type : \{{event_class}}.class, &)
          w = _event_handler_mutex.synchronize {
            if found = \{{handlers_list.id}}.find { |h| yield h }
              \{% if ::EventHandler::EMIT_COPY_ON_WRITE %}
                updated = \{{handlers_list.id}}.dup
                updated.delete found
                @\{{handlers_list.id}} = updated
              \{% else %}
                \{{handlers_list.id}}.delete found
              \{% end %}
              found
            end
          }
          _announce_removed type, w
        end

        # Removes *handler* from the list of handlers for event *type*.
        def off(type : \{{event_class}}.class, handler : ::Proc(\{{event_class}}, ::Nil))
          _off_first(type) { |h| h.handler == handler }
        end
        # :ditto:
        def off(type : \{{event_class}}.class, hash : ::UInt64)
          _off_first(type) { |h| h.handler_hash == hash }
        end
        # :ditto:
        def off(type : \{{event_class}}.class, wrapper : ::EventHandler::Wrapper(::Proc(::EventHandler::Event, ::Nil)))
          # Match by object identity (`same?`), not `==`. The stored handlers are
          # `Wrapper(Proc(\{{event_class}}, ::Nil))`, but this overload receives the
          # erased `Wrapper(Proc(::EventHandler::Event, ::Nil))` — the type handed
          # to `AddHandlerEvent`/`RemoveHandlerEvent` handlers via `unsafe_as`. A
          # `==` lookup would find nothing: `Reference#==`'s identity branch is
          # `==(other : self)`, which no longer applies once a stored
          # concrete-typed element is compared against the erased type, so the
          # catch-all `==(other) : false` matches every element (same erasure
          # pitfall as `off(type, at)`). The erased wrapper is still the same
          # object as the stored one, so locate it by identity; `_off_first`'s
          # `Array#delete found` then removes every identical copy correctly,
          # since that compares concrete-typed elements where identity applies.
          _off_first(type) { |h| h.same?(wrapper) }
        end
        # :ditto:
        def off(type : \{{event_class}}.class, at : ::Int)
          # Remove the handler at index *at* directly via `delete_at`. The list
          # holds `Wrapper(Proc(\{{event_class}}, ::Nil))`, but `off(type,
          # wrapper)` is restricted to the erased
          # `Wrapper(Proc(::EventHandler::Event, ::Nil))`, an unrelated type to
          # generics; passing the concrete-typed wrapper unchanged would instead
          # fall through to `off(type, emit = ...)`, wiping all handlers. Erasing
          # it with `unsafe_as` to reach `off(type, wrapper)` would remove
          # nothing either, since `Array#delete`'s `Reference#==` identity branch
          # no longer applies once compared against the erased type. Deleting by
          # index sidesteps both: no comparison, no type erasure.
          w = _event_handler_mutex.synchronize {
            if found = \{{handlers_list.id}}[at]?
              \{% if ::EventHandler::EMIT_COPY_ON_WRITE %}
                updated = \{{handlers_list.id}}.dup
                updated.delete_at at
                @\{{handlers_list.id}} = updated
              \{% else %}
                \{{handlers_list.id}}.delete_at at
              \{% end %}
              found
            end
          }
          _announce_removed type, w
        end

        # Removes all handlers for event *type*.
        #
        # If *emit* is false, `RemoveHandlerEvent`s are not emitted.
        #
        # If *emit* is true, a `RemoveHandlerEvent` is emitted once for every
        # distinct `Wrapper` object removed. See README for details.
        def remove_all_handlers(type : \{{event_class}}.class, emit = ::EventHandler.emit_on_remove_all?)
          if emit
            # Snapshot and clear the whole list in a single locked swap, then
            # emit one `RemoveHandlerEvent` per distinct wrapper. Calling `off`
            # once per wrapper instead would re-lock and rescan (or re-`dup`
            # under copy-on-write) the entire array each time — O(n²). Clearing
            # once is O(n).
            removed = _event_handler_mutex.synchronize {
              \{% if ::EventHandler::EMIT_COPY_ON_WRITE %}
                snapshot = \{{handlers_list.id}}
                @\{{handlers_list.id}} = ::Array(Wrapper(::Proc(\{{event_class}}, ::Nil))).new
              \{% else %}
                snapshot = \{{handlers_list.id}}.dup
                \{{handlers_list.id}}.clear
              \{% end %}
              snapshot
            }
            removed.uniq.each do |w|
              emit_remove_handler_event type, w
            end
          else
            _event_handler_mutex.synchronize {
              \{% if ::EventHandler::EMIT_COPY_ON_WRITE %}
                # Publish a fresh empty array rather than emptying one a
                # concurrent emit may be iterating.
                @\{{handlers_list.id}} = ::Array(Wrapper(::Proc(\{{event_class}}, ::Nil))).new
              \{% else %}
                \{{handlers_list.id}}.clear
              \{% end %}
            }
          end
          true
        end
        # :ditto:
        def off(type : \{{event_class}}.class, emit = ::EventHandler.emit_on_remove_all?)
          remove_all_handlers type, emit
        end

        # Returns the list of handlers for event *type*.
        def handlers(type : \{{event_class}}.class)
          \{{handlers_list.id}}
        end

        # Low-level function used to execute handlers and almost nothing else.
        # Regular users should use `#emit` instead.
        protected def _emit(type : \{{event_class}}.class, event : \{{event_class}}, async : ::Bool? = nil)
          \{% if ::EventHandler::EMIT_SKIP_WHEN_NO_HANDLERS %}
            # Fast path: with nothing subscribed, skip the mutex lock and the
            # per-emit `dup` allocation entirely. See
            # `EventHandler::EMIT_SKIP_WHEN_NO_HANDLERS`.
            return event if \{{handlers_list.id}}.empty?
          \{% end %}

          # Snapshot the handler list, then invoke the handlers. Handlers may
          # call `on`/`off`/`emit` or block on a `Channel`, so the list is never
          # iterated while a lock is held — that would deadlock.
          \{% if ::EventHandler::EMIT_COPY_ON_WRITE %}
            # Lock-free read. Under copy-on-write the array is never mutated in
            # place, so capturing the snapshot is a single atomic pointer load.
            # A concurrent writer publishes a brand-new array (under the write
            # lock) and swaps the reference; we keep iterating the array we
            # captured, which no one mutates. The mutex only serializes writers
            # against each other, not this read.
            #
            # Assumes the writer's reference-publishing store is visible here:
            # trivially true on the single-threaded fiber scheduler (writers
            # never yield mid-swap), and holds on strongly-ordered targets
            # (e.g. x86-TSO) under multi-threading — same benign-race assumption
            # as the empty-list fast path above. Flip `EMIT_COPY_ON_WRITE` off
            # to restore the locked, `dup`-based read.
            handlers = \{{handlers_list.id}}
          \{% else %}
            handlers = _event_handler_mutex.synchronize { \{{handlers_list.id}}.dup }
          \{% end %}

          # Invokes all registered handlers, collecting those meant to run only
          # once so they can be removed afterward.
          #
          # Once-handlers are removed in a single batched copy-on-write pass
          # after the loop, rather than calling `off` per fired once-handler:
          # the latter would re-lock the mutex and (under copy-on-write)
          # re-`dup` the entire array per handler — O(k) locks and O(k·n)
          # copying when k of n handlers fire once. Batching collapses that to
          # one lock and one array rebuild. `once_fired` stays `nil` (no
          # allocation) when no once-handler fires.
          once_fired = nil
          handlers.each do |handler|
            handler.call(event, async)
            if handler.once?
              (once_fired ||= ::Array(typeof(handler)).new) << handler
            end
          end

          if once_fired
            # Drop every fired once-handler in a single locked pass, recording
            # the distinct wrappers this pass actually removed so only those
            # are announced below.
            fired = once_fired
            removed = nil
            _event_handler_mutex.synchronize do
              \{% if ::EventHandler::EMIT_COPY_ON_WRITE %}
                # One pass over the snapshot both builds the fresh published
                # array (kept handlers) and collects the distinct fired wrappers
                # actually present (to announce) — halving the per-element
                # `fired.includes?` scans versus separate `reject`+`select`+`uniq`
                # passes. `kept` is a brand-new array (COW preserved); `removed`
                # holds the distinct wrappers in first-seen order.
                current = \{{handlers_list.id}}
                kept = fired.class.new
                dropped = nil
                current.each do |h|
                  if fired.includes?(h)
                    d = (dropped ||= fired.class.new)
                    d << h unless d.includes?(h)
                  else
                    kept << h
                  end
                end
                @\{{handlers_list.id}} = kept
                removed = dropped
              \{% else %}
                # `Array#delete` returns the element when it removed something and
                # `nil` when the wrapper was already gone, so this both performs
                # the removal and records which distinct wrappers were present.
                removed = fired.uniq.select { |h| !\{{handlers_list.id}}.delete(h).nil? }
              \{% end %}
            end
            # Announce each removal outside the lock, once per distinct wrapper.
            # A wrapper registered in several slots lands in `once_fired` once
            # per slot, but the batched removal above drops every identical copy
            # in one pass, so it must announce exactly once (`removed` is
            # de-duplicated). Only wrappers this pass actually removed are
            # announced: a fired once-handler may already have been dropped by
            # an `off` from another handler/fiber during this dispatch, which
            # already emitted its own `RemoveHandlerEvent` — re-announcing would
            # double-fire it.
            removed.try &.each { |h| emit_remove_handler_event type, h }
          end

          event
        end
        # :ditto:
        protected def _emit(type : \{{event_class}}.class, *args)
          _emit type, \{{event_class}}.new *args
        end

        # Emits *event* of *type*.
        #
        # When `EMIT_SKIP_WHEN_NO_HANDLERS`, `emit` gains a fast path: if neither
        # this concrete type nor the catch-all `AnyEvent` has any handler, it
        # returns immediately. It's `@[AlwaysInline]` so, in the common
        # no-subscriber case, the guard folds into the caller as two
        # `@size == 0` comparisons — no call into `_emit`, no lock, no
        # allocation. With the constant off, neither the annotation nor the
        # guard is generated and `emit` is the original two-line dispatch.
        \{% if ::EventHandler::EMIT_SKIP_WHEN_NO_HANDLERS %}@[AlwaysInline]\{% end %}
        def emit(type : \{{event_class}}.class, event : \{{event_class}})
          \{% if ::EventHandler::EMIT_SKIP_WHEN_NO_HANDLERS %}
            return event if \{{handlers_list.id}}.empty? && \{{any_handlers_list.id}}.empty?

            # Skip `AnyEvent` meta-dispatch when this event already IS
            # `AnyEvent`: `_emit(type, event)` below dispatches to the same
            # handler list, so re-dispatching would fire every `AnyEvent`
            # handler twice and wrap the event in a doubly-nested `AnyEvent`.
            # Emitting an `AnyEvent` directly happens via the module-level
            # `emit(event)` helper when the event is itself an `AnyEvent`.
            \{% if e != ::EventHandler::AnyEvent %}
              # Only dispatch to `AnyEvent` when something is listening: the
              # `_emit ::EventHandler::AnyEvent, event` call wraps the event in
              # a freshly-allocated `AnyEvent.new(event)` before `_emit` reaches
              # its empty-list fast path, so without this guard every emit with
              # concrete-type handlers but no `AnyEvent` listener would allocate
              # and immediately discard one.
              _emit ::EventHandler::AnyEvent, event unless \{{any_handlers_list.id}}.empty?
            \{% end %}
          \{% else %}
            # Never re-dispatch `AnyEvent` to itself, or its handlers fire
            # twice (and receive a doubly-wrapped event).
            \{% if e != ::EventHandler::AnyEvent %}
              _emit ::EventHandler::AnyEvent, event
            \{% end %}
          \{% end %}
          _emit(type, event)
        end
        # :ditto:
        \{% if ::EventHandler::EMIT_SKIP_WHEN_NO_HANDLERS %}@[AlwaysInline]\{% end %}
        def emit(type : \{{event_class}}.class, *args)
          \{% if ::EventHandler::EMIT_SKIP_WHEN_NO_HANDLERS %}
            # Build the event object only when something is listening.
            # `emit(type, event)` above also early-outs with no handlers, but
            # only after the object is constructed; the parameterless
            # per-frame emits (`PreRender`/`Rendered`/`Focus`, fired per widget
            # every frame with zero listeners in a typical app) would otherwise
            # heap-allocate an event immediately discarded. Guarding before
            # `.new` keeps that allocation off the hot path. NOTE: in the
            # no-listener case the splat form returns `nil`, so its return type
            # is nilable — callers needing the emitted object back must use the
            # explicit `emit(event)` form, which always constructs and returns it.
            return if \{{handlers_list.id}}.empty? && \{{any_handlers_list.id}}.empty?
          \{% end %}
          event =  \{{event_class}}.new *args
          emit type, event
        end

      \{% end %}

    \{% end %}
  end
end
