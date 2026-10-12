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
  class {{ name.id }}
    {% for property in properties %}
      {% if property.is_a?(Assign) %}
        getter {{ property.target.id }}
      {% elsif property.is_a?(TypeDeclaration) %}
        getter {{ property.var }} : {{ property.type }}
      {% else %}
        getter :{{ property.id }}
      {% end %}
    {% end %}

    def initialize({{
                     properties.map do |field|
                       "@#{field.id}".id
                     end.splat
                   }})
    end

    {{ yield }}

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
    class_record {{ e.id }} < ::EventHandler::Event{% if args.size > 0 %}, {{ args.splat }}{% end %}
  end

  # :nodoc:
  # EventHandler macro magic.
  #
  # Handler storage is lazy and per emitter. Every `Event` subclass gets a
  # compile-time index (its position in `names` below); an emitter carries a
  # bitmask with one bit per index, plus a `Hash` from index to the handler
  # list for that event, created on the first `on`. Nothing is allocated for
  # event types an emitter never subscribes to, and the no-listener `emit`
  # fast path is a single bit test. See `EventHandler::ErasedHandlers` for
  # the store's element type and the typed views over it.
  macro finished
    \{% begin %}
      \{% names = ::EventHandler::Event.all_subclasses.map { |e| e.name.split('(').first }.uniq %}
      \{% words = (names.size + 63) // 64 %}

      # Indices of the three meta-events, looked up once here.
      \{% any_idx = nil %}
      \{% add_idx = nil %}
      \{% remove_idx = nil %}
      \{% for name, idx in names %}
        \{% any_idx = idx if name == ::EventHandler::AnyEvent.name.stringify %}
        \{% add_idx = idx if name == ::EventHandler::AddHandlerEvent.name.stringify %}
        \{% remove_idx = idx if name == ::EventHandler::RemoveHandlerEvent.name.stringify %}
      \{% end %}

      # One bit per event type: set while this emitter holds at least one
      # handler for it. Inline in the object (no allocation); `_emit`'s
      # no-listener fast path reads it without taking the lock.
      @_event_handler_bits = ::StaticArray(::UInt64, \{{ words }}).new(0_u64)

      # The handler lists, keyed by event index, erased to a common element
      # type (see `ErasedHandlers`). `nil` until the first `on`; never holds
      # an empty list (the last `off` for a type removes its key), so a key's
      # presence and its bit agree once a write completes.
      #
      # Readers (`_emit`) never lock. A key is added or removed by publishing
      # a fresh `Hash` (copy-on-write at the map level, exactly as the lists
      # themselves under `EMIT_COPY_ON_WRITE`); replacing the list of an
      # existing key stores in place: the entry is rewritten with the same
      # hash and key, so a reader observes only the list reference, either
      # before or after the store. A reader may thus see the bit
      # and the map momentarily disagree, so every lock-free lookup treats
      # "key absent" as "no handlers" — the same benign race the bit already
      # has (see `EMIT_SKIP_WHEN_NO_HANDLERS`).
      @_event_handlers : ::Hash(::Int32, ::EventHandler::ErasedHandlers)?

      # Whether this emitter has handlers for the event at *idx*. Inlined so
      # that, with a literal *idx*, it folds into one load, mask and compare.
      @[AlwaysInline]
      private def _event_bit?(idx : ::Int32) : ::Bool
        (@_event_handler_bits.unsafe_fetch(idx >> 6) & (1_u64 << (idx & 63))) != 0_u64
      end

      # Lock-free lookup of the erased handler list for *idx*, or `nil`.
      private def _event_handlers_get(idx : ::Int32) : ::EventHandler::ErasedHandlers?
        if store = @_event_handlers
          store[idx]?
        end
      end

      # Publishes *list* as the handler list for *idx*, or drops the key when
      # *list* is empty. Caller holds `_event_handler_mutex`.
      private def _event_handlers_set(idx : ::Int32, list : ::EventHandler::ErasedHandlers) : ::Nil
        return _event_handlers_delete(idx) if list.empty?
        store = @_event_handlers
        if store && store.has_key?(idx)
          # Existing key: rewritten in place (same hash and key, the new
          # list), no reallocation or rehash.
          store[idx] = list

        else
          # New key: publish a fresh map so a lock-free reader never sees the
          # map mid-rehash.
          updated = store ? store.dup : ::Hash(::Int32, ::EventHandler::ErasedHandlers).new
          updated[idx] = list
          @_event_handlers = updated
        end
        @_event_handler_bits[idx >> 6] |= (1_u64 << (idx & 63))
      end

      # Drops the handler list for *idx*, if any. Caller holds
      # `_event_handler_mutex`.
      private def _event_handlers_delete(idx : ::Int32) : ::Nil
        @_event_handler_bits[idx >> 6] &= ~(1_u64 << (idx & 63))
        if (store = @_event_handlers) && store.has_key?(idx)
          if store.size == 1
            @_event_handlers = nil
          else
            updated = store.dup
            updated.delete idx
            @_event_handlers = updated
          end
        end
      end

      # The `Event` subclass registered at *idx*, for the whole-object
      # `remove_all_handlers` to announce removals from an erased list.
      private def _event_type_at(idx : ::Int32) : ::EventHandler::Event.class
        case idx
        \{% for name, idx in names %}
        when \{{ idx }} then \{{ name.id }}
        \{% end %}
        else
          raise ::IndexError.new("No event type at index #{idx}")
        end
      end

      \{% for name, idx in names %}
        \{% event_class = name.id %}
        \{% handlers_list = "_event_" + name.identify.underscore %}
        \{% typed_list = "::Array(::EventHandler::Wrapper(::Proc(#{event_class}, ::Nil)))".id %}

        # Lock-free typed view of this emitter's handler list for
        # `\{{ event_class }}`, or `nil` when it holds none. The stored list
        # is the erased spelling of exactly this type (see `ErasedHandlers`),
        # so the cast is a no-op.
        private def \{{ handlers_list.id }} : \{{ typed_list }}?
          if list = _event_handlers_get(\{{ idx }})
            list.unsafe_as(\{{ typed_list }})
          end
        end

        private def internal_insert(type : \{{event_class}}.class, wrapper : ::EventHandler::Wrapper(::Proc(::EventHandler::Event, ::Nil)))
          _event_handler_mutex.synchronize do
            current = \{{ handlers_list.id }}
            \{% if ::EventHandler::EMIT_COPY_ON_WRITE %}
              # Publish a fresh array so any in-flight `_emit` keeps iterating
              # its captured snapshot. See `EMIT_COPY_ON_WRITE`.
              updated = current ? current.dup : \{{ typed_list }}.new(1)
            \{% else %}
              updated = current || \{{ typed_list }}.new(1)
            \{% end %}
            updated.insert wrapper.at, wrapper
            _event_handlers_set \{{ idx }}, updated.unsafe_as(::EventHandler::ErasedHandlers)
          end

          # Only build+dispatch the `AddHandlerEvent` when something is listening
          # for it. `_emit AddHandlerEvent, ...` constructs a fresh
          # `AddHandlerEvent.new(...)` wrapper before `_emit` reaches its
          # empty-list fast path, so without this guard every `on()` would
          # allocate and immediately discard one. Same idea as the `AnyEvent`
          # guard in `emit`.
          \{% if ::EventHandler::EMIT_SKIP_WHEN_NO_HANDLERS %}
            if _event_bit?(\{{ add_idx }})
              _emit ::EventHandler::AddHandlerEvent, type, wrapper.unsafe_as(::EventHandler::Wrapper(::Proc(::EventHandler::Event, ::Nil)))
            end
          \{% else %}
            _emit ::EventHandler::AddHandlerEvent, type, wrapper.unsafe_as(::EventHandler::Wrapper(::Proc(::EventHandler::Event, ::Nil)))
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
        #
        # Returns an `EventHandler::Subscription` — a self-contained
        # disconnect handle: `sub.off` removes exactly this handler, with no
        # need to restate the event type or hold the `Wrapper` (cf. Qt's
        # `QMetaObject::Connection`). The `Wrapper` itself still flows to
        # `AddHandlerEvent`/`RemoveHandlerEvent` listeners, and the
        # `off(type, handler/hash/at)` forms keep working for callers that
        # kept those instead.
        def on(type : \{{event_class}}.class, handler : ::Proc(\{{event_class}}, ::Nil), once = false, async = ::EventHandler.async?, at = ::EventHandler.at_end) : ::EventHandler::Subscription
          w = internal_insert type, handler, once, async, at
          # Erased for the identity-matched `off(type, wrapper)` overload —
          # the concrete-typed wrapper would fall through to the wipe-all
          # `off(type, emit)` (see that overload's comment).
          erased = w.unsafe_as(::EventHandler::Wrapper(::Proc(::EventHandler::Event, ::Nil)))
          ::EventHandler::Subscription.new(-> { off(type, erased); nil }, erased)
        end
        # Re-registers the `Wrapper` behind *subscription* — the
        # subscription-typed spelling of `on(type, wrapper)`. Raises
        # `ArgumentError` when the subscription carries no wrapper (see
        # `Subscription#wrapper`).
        def on(type : \{{event_class}}.class, subscription : ::EventHandler::Subscription) : ::EventHandler::Subscription
          w = subscription.wrapper || raise ::ArgumentError.new("Subscription armed via #on carries no wrapper to re-register")
          # Un-erase for insertion: `internal_insert` stores into the
          # concrete-typed handler list, and instantiating it with the erased
          # static type would not compile. The wrapper object itself IS the
          # concrete one `on(type, handler)` built.
          on type, w.unsafe_as(::EventHandler::Wrapper(::Proc(\{{event_class}}, ::Nil)))
        end
        # Removes the handler behind *subscription* — the subscription-typed
        # spelling of `off(type, wrapper)`; returns the removed wrapper, or
        # nil when it was no longer registered (or the subscription carries
        # no wrapper).
        def off(type : \{{event_class}}.class, subscription : ::EventHandler::Subscription)
          subscription.wrapper.try { |w| off type, w }
        end
        # :ditto:
        def on(type : \{{event_class}}.class, *, once = false, async = ::EventHandler.async?, at = ::EventHandler.at_end, &handler : \{{event_class}} -> ::Nil) : ::EventHandler::Subscription
          on type, handler, once, async, at
        end
        # :ditto:
        def on(type : \{{event_class}}.class, wrapper : ::EventHandler::Wrapper(::Proc(::EventHandler::Event, ::Nil))) : ::EventHandler::Subscription
          internal_insert type, wrapper
          # Normalize to the erased spelling for storage on the Subscription:
          # this method instantiates per call-site argument type, so *wrapper*
          # may statically be the concrete `Wrapper(Proc(\{{event_class}}, Nil))`
          # here, which the erased-typed `Subscription#wrapper` slot rejects.
          erased = wrapper.unsafe_as(::EventHandler::Wrapper(::Proc(::EventHandler::Event, ::Nil)))
          ::EventHandler::Subscription.new(-> { off(type, erased); nil }, erased)
        end
        # Adds an autogenerated handler which sends emitted events to *channel*
        def on(type : \{{event_class}}.class, channel : ::Channel(\{{event_class}}), once = false, async = ::EventHandler.async?, at = ::EventHandler.at_end) : ::EventHandler::Subscription
          on(type, once: once, async: async, at: at) { |e| channel.send e; true }
        end

        # Per-event subscribe sugar, named after the event itself (the
        # underscored last path component of the event class: `event Clicked`
        # also defines `on_clicked(&)` on every emitter). Equivalent to
        # `on(\{{event_class}}) { |e| ... }`; returns the
        # `EventHandler::Subscription` (see `on`). Emitters may shadow a
        # generated method with a richer hand-written adapter (one yielding the
        # event's payload instead of the event).
        #
        # Skipped for an event nested inside another event class (e.g. a
        # per-key `KeyPress::<member>` family): the last name component alone
        # is ambiguous there — it can collide with an unrelated top-level
        # event of the same name — and such families are typically generated
        # and huge. Subscribe to those with the explicit `on(Type) { }` form.
        \{% enclosing = event_class.stringify.split("::")[0..-2].join("::") %}
        \{% enclosing_type = enclosing.empty? ? nil : parse_type(enclosing).resolve? %}
        \{% unless enclosing_type && enclosing_type < ::EventHandler::Event %}
          \{% sugar_name = "on_" + event_class.stringify.split("::").last.underscore %}
          # Options are keyword-only (bare `*`, like the block overload of
          # `on`): with untyped positionals an emitter's own same-name sugar
          # taking positional args (e.g. Crysterm's `on_key('q', :escape)`)
          # would bind them to `once`/`async` here and fail deep in
          # `internal_insert` instead of resolving to that overload.
          def \{{sugar_name.id}}(*, once = false, async = ::EventHandler.async?, at = ::EventHandler.at_end, &handler : \{{event_class}} -> ::Nil) : ::EventHandler::Subscription
            on \{{event_class}}, handler, once, async, at
          end
        \{% end %}

        # Adds *handler* to the list of handlers for event *type*; removed
        # automatically after it triggers once. Returns an
        # `EventHandler::Subscription` (see `on`); its `#off` is a no-op after
        # the handler has auto-fired away.
        #
        # Equivalent to `on` with argument *once*.
        def once(type : \{{event_class}}.class, handler : ::Proc(\{{event_class}}, ::Nil), async = ::EventHandler.async?, at = ::EventHandler.at_end) : ::EventHandler::Subscription
          on type, handler, true, async, at
        end
        # :ditto:
        def once(type : \{{event_class}}.class, async = ::EventHandler.async?, at = ::EventHandler.at_end, &handler : \{{event_class}} -> ::Nil) : ::EventHandler::Subscription
          on type, handler, true, async, at
        end
        # Adds an autogenerated handler which sends emitted events to *channel*;
        # removed automatically after it triggers once.
        #
        # Equivalent to `on` with argument *once*.
        def once(type : \{{event_class}}.class, channel : ::Channel(\{{event_class}}), async = ::EventHandler.async?, at = ::EventHandler.at_end) : ::EventHandler::Subscription
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
            if _event_bit?(\{{ remove_idx }})
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
            if (list = \{{ handlers_list.id }}) && (found = list.find { |h| yield h })
              \{% if ::EventHandler::EMIT_COPY_ON_WRITE %}
                updated = list.dup
                updated.delete found
              \{% else %}
                updated = list
                updated.delete found
              \{% end %}
              _event_handlers_set \{{ idx }}, updated.unsafe_as(::EventHandler::ErasedHandlers)
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
            if (list = \{{ handlers_list.id }}) && (found = list[at]?)
              \{% if ::EventHandler::EMIT_COPY_ON_WRITE %}
                updated = list.dup
                updated.delete_at at
              \{% else %}
                updated = list
                updated.delete_at at
              \{% end %}
              _event_handlers_set \{{ idx }}, updated.unsafe_as(::EventHandler::ErasedHandlers)
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
          # Detach the whole list in a single locked pass, then emit one
          # `RemoveHandlerEvent` per distinct wrapper. Calling `off` once per
          # wrapper instead would re-lock and rescan (or re-`dup` under
          # copy-on-write) the entire array each time — O(n²). Detaching once
          # is O(n).
          removed = _event_handler_mutex.synchronize {
            if list = \{{ handlers_list.id }}
              \{% if ::EventHandler::EMIT_COPY_ON_WRITE %}
                # Drop the published list rather than emptying one a
                # concurrent emit may be iterating.
                snapshot = list
              \{% else %}
                snapshot = list.dup
                list.clear
              \{% end %}
              _event_handlers_delete \{{ idx }}
              snapshot
            end
          }
          if emit && removed
            removed.uniq.each do |w|
              emit_remove_handler_event type, w
            end
          end
          true
        end
        # :ditto:
        def off(type : \{{event_class}}.class, emit = ::EventHandler.emit_on_remove_all?)
          remove_all_handlers type, emit
        end

        # Returns the list of handlers for event *type*; an empty array when
        # none is installed.
        def handlers(type : \{{event_class}}.class)
          \{% if ::EventHandler::EMIT_COPY_ON_WRITE %}
            # Under copy-on-write, lock-free `_emit` relies on the published
            # array never being mutated in place. Hand back a `dup` so a caller
            # mutating the result can't corrupt an in-flight dispatch's snapshot.
            \{{ handlers_list.id }}.try(&.dup) || \{{ typed_list }}.new
          \{% else %}
            \{{ handlers_list.id }} || \{{ typed_list }}.new
          \{% end %}
        end

        # Whether any handler is registered for *type*. Allocation-free
        # (unlike `handlers(type).any?`, which dups the COW list).
        def has_handlers?(type : \{{event_class}}.class) : Bool
          _event_bit?(\{{ idx }})
        end

        # Low-level function used to execute handlers and almost nothing else.
        # Regular users should use `#emit` instead.
        protected def _emit(type : \{{event_class}}.class, event : \{{event_class}}, async : ::Bool? = nil)
          \{% if ::EventHandler::EMIT_SKIP_WHEN_NO_HANDLERS %}
            # Fast path: with nothing subscribed, skip the store lookup (and,
            # without copy-on-write, the lock and `dup`) entirely. See
            # `EventHandler::EMIT_SKIP_WHEN_NO_HANDLERS`.
            return event unless _event_bit?(\{{ idx }})
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
            handlers = \{{ handlers_list.id }}
          \{% else %}
            handlers = _event_handler_mutex.synchronize { \{{ handlers_list.id }}.try &.dup }
          \{% end %}
          # The bit may run ahead of the store (see `@_event_handlers`), or
          # the fast path above may be compiled out: no list means no handlers.
          return event unless handlers

          # Invokes all registered handlers.
          #
          # A once-handler is removed from the published list *before* it runs,
          # not after: the removal is its claim. Every dispatch — this one, a
          # nested one started by a handler re-emitting the event, or one on
          # another fiber — iterates its own snapshot, so a fired once-handler
          # can appear in several of them; whichever dispatch removes it first
          # runs it, and the others find nothing to remove and skip it. (With
          # removal after the call, a nested dispatch would run it a second
          # time; for `wait`'s implicit channel handler that second `send` has
          # no receiver and blocks the emitter forever.) Same order as Node's
          # `EventEmitter#once`. Consequences: a once-handler that raises is
          # already gone, a once-handler `off`'d mid-dispatch by an earlier
          # handler no longer runs, and a once-handler may re-register itself
          # from inside its own body and stay registered.
          #
          # Per fired once-handler this costs one lock and (under copy-on-write)
          # one array copy — the same as the single batched pass it replaces
          # when one once-handler fires per emit, which is the usual case
          # (`wait`, a single `once`). The `RemoveHandlerEvent` is emitted by
          # `_off_first`, outside the lock, before the handler runs.
          handlers.each do |handler|
            if handler.once?
              next unless _off_first(type) { |h| h.same?(handler) }
            end
            handler.call(event, async)
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
        # no-subscriber case, the guard folds into the caller as two bit tests
        # on the emitter's subscription mask — no call into `_emit`, no lock,
        # no allocation. With the constant off, neither the annotation nor the
        # guard is generated and `emit` is the original two-line dispatch.
        \{% if ::EventHandler::EMIT_SKIP_WHEN_NO_HANDLERS %}@[AlwaysInline]\{% end %}
        def emit(type : \{{event_class}}.class, event : \{{event_class}})
          \{% if ::EventHandler::EMIT_SKIP_WHEN_NO_HANDLERS %}
            return event unless _event_bit?(\{{ idx }}) || _event_bit?(\{{ any_idx }})

            # Skip `AnyEvent` meta-dispatch when this event already IS
            # `AnyEvent`: `_emit(type, event)` below dispatches to the same
            # handler list, so re-dispatching would fire every `AnyEvent`
            # handler twice and wrap the event in a doubly-nested `AnyEvent`.
            # Emitting an `AnyEvent` directly happens via the module-level
            # `emit(event)` helper when the event is itself an `AnyEvent`.
            \{% if idx != any_idx %}
              # Only dispatch to `AnyEvent` when something is listening: the
              # `_emit ::EventHandler::AnyEvent, event` call wraps the event in
              # a freshly-allocated `AnyEvent.new(event)` before `_emit` reaches
              # its empty-list fast path, so without this guard every emit with
              # concrete-type handlers but no `AnyEvent` listener would allocate
              # and immediately discard one.
              _emit ::EventHandler::AnyEvent, event if _event_bit?(\{{ any_idx }})
            \{% end %}
          \{% else %}
            # Never re-dispatch `AnyEvent` to itself, or its handlers fire
            # twice (and receive a doubly-wrapped event).
            \{% if idx != any_idx %}
              _emit ::EventHandler::AnyEvent, event
            \{% end %}
          \{% end %}
          _emit(type, event)
        end
        # :ditto:
        #
        # Returns `Nil`, unconditionally: with no listener the event object is
        # never built (see below), so there would be nothing to return, and a
        # return type that depends on whether anyone happens to be subscribed is
        # not a usable contract. A caller that needs the emitted object back
        # constructs it itself and uses the `emit(type, event)` form, which
        # always returns it.
        \{% if ::EventHandler::EMIT_SKIP_WHEN_NO_HANDLERS %}@[AlwaysInline]\{% end %}
        def emit(type : \{{event_class}}.class, *args) : ::Nil
          \{% if ::EventHandler::EMIT_SKIP_WHEN_NO_HANDLERS %}
            # Build the event object only when something is listening.
            # `emit(type, event)` above also early-outs with no handlers, but
            # only after the object is constructed; the parameterless
            # per-frame emits (`PreRender`/`Rendered`/`Focus`, fired per widget
            # every frame with zero listeners in a typical app) would otherwise
            # heap-allocate an event immediately discarded. Guarding before
            # `.new` keeps that allocation off the hot path.
            return unless _event_bit?(\{{ idx }}) || _event_bit?(\{{ any_idx }})
          \{% end %}
          event =  \{{event_class}}.new *args
          emit type, event
        end

      \{% end %}

      # Removes every handler this emitter carries, for every event type — the
      # whole-object counterpart of `remove_all_handlers(type)`. Use it when the
      # emitter itself is being torn down and nothing subscribed to it should
      # keep running (or keep the emitter, and whatever its handlers captured,
      # alive).
      #
      # Handlers this object registered on *other* emitters are unaffected —
      # nothing links them back here. Cancel those through the
      # `Subscription`/`Subscriptions` they returned.
      #
      # *emit* controls `RemoveHandlerEvent` emission as in
      # `remove_all_handlers(type, emit)`; it defaults to off here, since a
      # torn-down emitter has no use for the notifications. When on, the
      # `RemoveHandlerEvent` listeners present at the call see every other
      # type's removals first, and are then removed last — with nothing left
      # to announce that to, exactly as `remove_all_handlers(RemoveHandlerEvent,
      # true)` behaves.
      #
      # Without announcements this is a single lock, whatever the number of
      # event types: the store is detached and the subscription mask zeroed
      # in one pass.
      def remove_all_handlers(emit = false) : ::Nil
        store = _event_handler_mutex.synchronize {
          detached = @_event_handlers
          @_event_handlers = nil
          @_event_handler_bits = ::StaticArray(::UInt64, \{{ words }}).new(0_u64)
          # Keep the announcement listeners installed until the end.
          if emit && detached && (listeners = detached[\{{ remove_idx }}]?)
            _event_handlers_set \{{ remove_idx }}, listeners
          end
          detached
        }
        return unless emit && store
        store.each do |idx, list|
          next if idx == \{{ remove_idx }}
          type = _event_type_at idx
          # The list is erased, but the announcement wants erased wrappers
          # anyway (see `emit_remove_handler_event`); `uniq` compares by
          # identity, which erasure preserves.
          list.uniq.each do |w|
            \{% if ::EventHandler::EMIT_SKIP_WHEN_NO_HANDLERS %}
              break unless _event_bit?(\{{ remove_idx }})
            \{% end %}
            _emit ::EventHandler::RemoveHandlerEvent, type, w
          end
        end
        remove_all_handlers ::EventHandler::RemoveHandlerEvent, true
      end

    \{% end %}
  end
end
