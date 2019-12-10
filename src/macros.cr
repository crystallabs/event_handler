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
                     *properties.map do |field|
                       "@#{field.id}".id
                     end
                   }})
    end

    {{yield}}

    def copy_with({{
                    *properties.map do |property|
                      if property.is_a?(Assign)
                        "#{property.target.id} _#{property.target.id} = @#{property.target.id}".id
                      elsif property.is_a?(TypeDeclaration)
                        "#{property.var.id} _#{property.var.id} = @#{property.var.id}".id
                      else
                        "#{property.id} _#{property.id} = @#{property.id}".id
                      end
                    end
                  }})
      self.class.new({{
                       *properties.map do |property|
                         if property.is_a?(Assign)
                           "_#{property.target.id}".id
                         elsif property.is_a?(TypeDeclaration)
                           "_#{property.var.id}".id
                         else
                           "_#{property.id}".id
                         end
                       end
                     }})
    end

    def clone
      self.class.new({{
                       *properties.map do |property|
                         if property.is_a?(Assign)
                           "@#{property.target.id}.clone".id
                         elsif property.is_a?(TypeDeclaration)
                           "@#{property.var.id}.clone".id
                         else
                           "@#{property.id}.clone".id
                         end
                       end
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
    class_record {{e.id}} < ::EventHandler::Event{% if args.size > 0 %}, {{ *args }}{% end %}
  end

  # :nodoc:
  # EventHandler macro magic
  macro finished
    \{% begin %}
      \{% for e in ::EventHandler::Event.all_subclasses %}
        \{% handlers_list = "_event_" + e.name.identify.underscore.tr("()","__").stringify %}
        \{% event_class = e.name.split('(').first.id %}

        private getter \{{handlers_list.id}} = ::Array(Wrapper(::Proc(\{{event_class}}, ::Nil))).new

        private def internal_insert(type : \{{event_class}}.class, wrapper : ::EventHandler::Wrapper(::Proc(::EventHandler::Event, ::Nil)))
          \{{handlers_list.id}}.insert wrapper.at, wrapper

          # Use this:
          _emit ::EventHandler::AddHandlerEvent, type, wrapper.unsafe_as(::EventHandler::Wrapper(::Proc(::EventHandler::Event, ::Nil)))

          # Or this:
          #handler2 = ::Proc(::EventHandler::Event,::Nil).new do |e| wrapper.handler.call e.as \ { {e.id}} end
          #wrapper2 = ::EventHandler::Wrapper(::Proc(::EventHandler::Event, ::Nil)).new handler2, wrapper.once?, wrapper.async?, wrapper.at
          #_emit ::EventHandler::AddHandlerEvent, type, wrapper2

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

        # Removes *handler* from list of handlers for event *type*.
        def off(type : \{{event_class}}.class, handler : ::Proc(\{{event_class}}, ::Nil))
          if wrapper = \{{handlers_list.id}}.find {|h| h.handler == handler }
            off type, wrapper
          end
        end
        # :ditto:
        def off(type : \{{event_class}}.class, hash : ::UInt64)
          if wrapper = \{{handlers_list.id}}.find {|h| h.handler_hash == hash }
            off type, wrapper
          end
        end
        # :ditto:
        def off(type : \{{event_class}}.class, wrapper : ::EventHandler::Wrapper(::Proc(::EventHandler::Event, ::Nil)))
          if w = \{{handlers_list.id}}.delete wrapper

            # Use this:
            _emit ::EventHandler::RemoveHandlerEvent, type, w.unsafe_as(::EventHandler::Wrapper(::Proc(::EventHandler::Event, ::Nil)))

            # Or this:
            #handler2 = ::Proc(::EventHandler::Event,::Nil).new do |e| wrapper.handler.call e.as \ { {e.id}} end
            #wrapper2 = ::EventHandler::Wrapper(::Proc(::EventHandler::Event, ::Nil)).new handler2, wrapper.once?, wrapper.async?, wrapper.at
            #_emit ::EventHandler::RemoveHandlerEvent, type, wrapper2

           w
          end
        end
        # :ditto:
        def off(type : \{{event_class}}.class, at : ::Int)
          off type, \{{handlers_list.id}}[at]
        end

        # Removes all handlers for event *type*.
        #
        # If *emit* is false, `RemoveHandlerEvent`s are not emitted.
        #
        # If *emit* is true, `RemoveHandlerEvent`s is emitted once for every distinct `Wrapper` object removed.
        # See README for detailed description of this behavior.
        def remove_all_handlers(type : \{{event_class}}.class, emit = ::EventHandler.emit_on_remove_all?)
          if emit
            wrappers = \{{handlers_list.id}}.dup.uniq
            wrappers.each do |w|
              off type, w
            end
          else
            \{{handlers_list.id}}.clear
          end
          true
        end
        # :ditto:
        def off(*arg)
          remove_all_handlers *arg
        end

        # Returns list of handlers for event *type*.
        def handlers(type : \{{event_class}}.class)
          \{{handlers_list.id}}
        end

        # Low-level function used to execute handlers and almost nothing else.
        # Regular users should use `#emit` instead.
        protected def _emit(type : \{{event_class}}.class, event : \{{event_class}}, async : ::Bool? = nil)
          # This loop invokes all registered handlers, and also removes
          # those which were intended to run only once.
          \{{handlers_list.id}}.dup.each do |handler|
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
        def emit(type : \{{event_class}}.class, event : \{{event_class}})
          _emit ::EventHandler::AnyEvent, event
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
