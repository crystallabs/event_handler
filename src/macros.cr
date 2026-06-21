# Creates class *name* in a single line, like one would do with the usual `record` macro for structs.
#
# Unlike `record` which creates structs, `class_record` creates classes.
# The properties on the object are still exposed as getters and not getters+setters.
# This may change in the future.
#
# This macro code is a copy of Crystal's 0.31.1 macro `record`, adjusted for this purpose.
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
  # Since events are classes, they can be also created manually.
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

        private getter \{{handlers_list.id}} = ::Array(Wrapper(::Proc(\{{event_class}}, ::Nil))).new

        private def internal_insert(type : \{{event_class}}.class, wrapper : ::EventHandler::Wrapper(::Proc(::EventHandler::Event, ::Nil)))
          _event_handler_mutex.synchronize do
            \{% if ::EventHandler::EMIT_COPY_ON_WRITE %}
              # Copy-on-write: publish a fresh array so any in-flight `_emit`
              # keeps iterating its captured snapshot. See `EMIT_COPY_ON_WRITE`.
              updated = \{{handlers_list.id}}.dup
              updated.insert wrapper.at, wrapper
              @\{{handlers_list.id}} = updated
            \{% else %}
              \{{handlers_list.id}}.insert wrapper.at, wrapper
            \{% end %}
          end

          # Only build+dispatch the `AddHandlerEvent` when something is listening
          # for it. The `_emit AddHandlerEvent, ...` path constructs a fresh
          # `AddHandlerEvent.new(...)` wrapper *before* `_emit` reaches its own
          # empty-list fast path, so without this guard every `on()` would
          # allocate — and immediately discard — an `AddHandlerEvent` even when
          # nobody subscribed to it. Same idea as the `AnyEvent` guard in `emit`.
          \{% if ::EventHandler::EMIT_SKIP_WHEN_NO_HANDLERS %}
            \{% add_handlers_list = "_event_" + ::EventHandler::AddHandlerEvent.name.identify.underscore.tr("()", "__").stringify %}
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

        # Adds *handler* to list of handlers for event *type*.
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

        # Adds *handler* to list of handlers for event *type*.
        # After it triggers once, it is automatically removed.
        #
        # The same behavior is obtained using `on` and providing argument *once*.
        def once(type : \{{event_class}}.class, handler : ::Proc(\{{event_class}}, ::Nil), async = ::EventHandler.async?, at = ::EventHandler.at_end)
          on type, handler, true, async, at
        end
        # :ditto:
        def once(type : \{{event_class}}.class, async = ::EventHandler.async?, at = ::EventHandler.at_end, &handler : \{{event_class}} -> ::Nil)
          on type, handler, true, async, at
        end
        # Adds an autogenerated handler which sends emitted events to *channel*
        # After it triggers once, it is automatically removed.
        #
        # The same behavior is obtained using `on` and providing argument *once*.
        def once(type : \{{event_class}}.class, channel : ::Channel(\{{event_class}}), async = ::EventHandler.async?, at = ::EventHandler.at_end)
          on type, channel, true, async, at
        end

        # Blocks until event *type* is emitted and executes *handler*.
        def wait(type : \{{event_class}}.class, handler : ::Proc(\{{event_class}}, ::Nil)?, async = ::EventHandler.async?, at = ::EventHandler.at_end, async_send = ::EventHandler.async_send?)
          channel = ::Channel(\{{event_class}}).new
          channel_wrapper = once type, channel, async_send, at
          handler_wrapper = wrapper type, handler, true, async, at
          e = channel.receive
          handler_wrapper.call e
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
        # handlers for *type*. Always called *outside* the handler-list lock, so
        # a `RemoveHandlerEvent` handler may freely call back into `on`/`off`.
        private def emit_remove_handler_event(type : \{{event_class}}.class, w : ::EventHandler::Wrapper(::Proc(\{{event_class}}, ::Nil)))
          # Skip building the `RemoveHandlerEvent` wrapper when nobody listens for
          # it — `_emit` would otherwise allocate it before its empty-list fast
          # path. Mirrors the `AddHandlerEvent` guard in `internal_insert`.
          \{% if ::EventHandler::EMIT_SKIP_WHEN_NO_HANDLERS %}
            \{% remove_handlers_list = "_event_" + ::EventHandler::RemoveHandlerEvent.name.identify.underscore.tr("()", "__").stringify %}
            unless \{{remove_handlers_list.id}}.empty?
              _emit ::EventHandler::RemoveHandlerEvent, type, w.unsafe_as(::EventHandler::Wrapper(::Proc(::EventHandler::Event, ::Nil)))
            end
          \{% else %}
            _emit ::EventHandler::RemoveHandlerEvent, type, w.unsafe_as(::EventHandler::Wrapper(::Proc(::EventHandler::Event, ::Nil)))
          \{% end %}
        end

        # Removes *handler* from list of handlers for event *type*.
        def off(type : \{{event_class}}.class, handler : ::Proc(\{{event_class}}, ::Nil))
          # Single pass: locate *and* remove the wrapper under one lock, instead
          # of a `find` scan followed by a second `off`/`delete` scan (and a
          # second lock acquisition).
          w = _event_handler_mutex.synchronize {
            if found = \{{handlers_list.id}}.find { |h| h.handler == handler }
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
          if w
            emit_remove_handler_event type, w
            w
          end
        end
        # :ditto:
        def off(type : \{{event_class}}.class, hash : ::UInt64)
          w = _event_handler_mutex.synchronize {
            if found = \{{handlers_list.id}}.find { |h| h.handler_hash == hash }
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
          if w
            emit_remove_handler_event type, w
            w
          end
        end
        # :ditto:
        def off(type : \{{event_class}}.class, wrapper : ::EventHandler::Wrapper(::Proc(::EventHandler::Event, ::Nil)))
          if w = _event_handler_mutex.synchronize {
                   \{% if ::EventHandler::EMIT_COPY_ON_WRITE %}
                     # Copy-on-write delete: only publish a fresh array when the
                     # wrapper was actually present. See `EMIT_COPY_ON_WRITE`.
                     updated = \{{handlers_list.id}}.dup
                     deleted = updated.delete wrapper
                     @\{{handlers_list.id}} = updated if deleted
                     deleted
                   \{% else %}
                     \{{handlers_list.id}}.delete wrapper
                   \{% end %}
                 }

            emit_remove_handler_event type, w
           w
          end
        end
        # :ditto:
        def off(type : \{{event_class}}.class, at : ::Int)
          off type, _event_handler_mutex.synchronize { \{{handlers_list.id}}[at] }
        end

        # Removes all handlers for event *type*.
        #
        # If *emit* is false, `RemoveHandlerEvent`s are not emitted.
        #
        # If *emit* is true, `RemoveHandlerEvent`s is emitted once for every distinct `Wrapper` object removed.
        # See README for detailed description of this behavior.
        def remove_all_handlers(type : \{{event_class}}.class, emit = ::EventHandler.emit_on_remove_all?)
          if emit
            # Snapshot and clear the whole list in a single locked swap, then
            # emit one `RemoveHandlerEvent` per distinct wrapper. The previous
            # implementation called `off` once per wrapper, and every `off`
            # re-locked and rescanned (or, with copy-on-write, re-`dup`ed) the
            # entire array — O(n²). Clearing once is O(n).
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
                # Copy-on-write clear: publish a fresh empty array rather than
                # emptying one a concurrent emit may be iterating.
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

        # Returns list of handlers for event *type*.
        def handlers(type : \{{event_class}}.class)
          \{{handlers_list.id}}
        end

        # Low-level function used to execute handlers and almost nothing else.
        # Regular users should use `#emit` instead.
        protected def _emit(type : \{{event_class}}.class, event : \{{event_class}}, async : ::Bool? = nil)
          \{% if ::EventHandler::EMIT_SKIP_WHEN_NO_HANDLERS %}
            # Fast path: with nothing subscribed to this type there is no snapshot
            # to take and no handler to call, so skip the mutex lock and the
            # otherwise-per-emit `dup` allocation entirely. See
            # `EventHandler::EMIT_SKIP_WHEN_NO_HANDLERS`.
            return event if \{{handlers_list.id}}.empty?
          \{% end %}

          # Take a snapshot of the handler list, then invoke the handlers. Handlers
          # may call `on`/`off`/`emit` or block on a `Channel`, so the list is
          # never iterated while a lock is held — that would deadlock.
          \{% if ::EventHandler::EMIT_COPY_ON_WRITE %}
            # Lock-free read. Under copy-on-write the array is never mutated in
            # place, so capturing the snapshot is a single atomic pointer load —
            # no lock needed. A concurrent writer publishes a brand-new array
            # (under the write lock) and swaps the reference; we keep iterating
            # the array we captured, which no one mutates. The mutex is therefore
            # only needed to serialize *writers* against each other, not to guard
            # this read.
            #
            # The one assumption is that the writer's reference-publishing store
            # is visible here. On the single-threaded fiber scheduler this is
            # trivially true (writers never yield mid-swap); under multi-threading
            # it holds on strongly-ordered targets (e.g. x86-TSO) and is the same
            # benign-race assumption the empty-list fast path above already makes.
            # Flip `EMIT_COPY_ON_WRITE` off to restore the locked, `dup`-based read.
            handlers = \{{handlers_list.id}}
          \{% else %}
            handlers = _event_handler_mutex.synchronize { \{{handlers_list.id}}.dup }
          \{% end %}

          # This loop invokes all registered handlers, and also removes
          # those which were intended to run only once.
          handlers.each do |handler|
            handler.call(event, async)
            if handler.once?
              off type, handler
            end
            #handler.once?
          end
          # (Alternatively, instead of 'each/if once?/off', use 'reject!/once?'

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
        # returns immediately. It is also `@[AlwaysInline]` so that, in that
        # (common) no-subscriber case, the guard folds into the caller as two
        # `@size == 0` comparisons — no call into `_emit`, no lock, no allocation.
        # When something *is* listening, the two `_emit` calls run as before (each
        # self-guards, so an empty side is still skipped). With the constant off,
        # neither the annotation nor the guard is generated and `emit` is verbatim
        # the original two-line dispatch.
        \{% if ::EventHandler::EMIT_SKIP_WHEN_NO_HANDLERS %}@[AlwaysInline]\{% end %}
        def emit(type : \{{event_class}}.class, event : \{{event_class}})
          \{% if ::EventHandler::EMIT_SKIP_WHEN_NO_HANDLERS %}
            \{% any_handlers_list = "_event_" + ::EventHandler::AnyEvent.name.identify.underscore.tr("()", "__").stringify %}
            return event if \{{handlers_list.id}}.empty? && \{{any_handlers_list.id}}.empty?

            # Only dispatch to `AnyEvent` when something is actually listening
            # for it. The `_emit ::EventHandler::AnyEvent, event` call wraps the
            # event in a freshly-allocated `AnyEvent.new(event)` *before* `_emit`
            # reaches its own empty-list fast path, so without this guard every
            # emit that has concrete-type handlers but no `AnyEvent` listener (the
            # common case) would allocate — and immediately discard — an
            # `AnyEvent` wrapper. Guarding here keeps that allocation off the hot
            # path. When an `AnyEvent` handler exists, behavior is unchanged.
            _emit ::EventHandler::AnyEvent, event unless \{{any_handlers_list.id}}.empty?
          \{% else %}
            _emit ::EventHandler::AnyEvent, event
          \{% end %}
          _emit(type, event)
        end
        # :ditto:
        def emit(type : \{{event_class}}.class, *args)
          event =  \{{event_class}}.new *args
          emit type, event
        end

      \{% end %}

    \{% end %}
  end
end
