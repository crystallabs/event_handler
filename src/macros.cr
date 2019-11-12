# Creates class *name* in a single line, like one would do with the usual `record` macro for structs.
#
# Unlike `record` which creates structs, `class_record` creates classes.
# The properties on the object are still exposed as getters and not getters+setters.
# This may change in the future.
#
# This macro code is a copy of Crystal's 0.31.1 macro `record`, adjusted for this purpose.
#
# ```
# class_record MyClass, a : Int32, b : String, c : Bool
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
  # event MouseClick, x : Int32, y : Int32
  # ```
  macro event(e, *args)
    class_record {{e.id}} < ::EventHandler::Event{% if args.size > 0 %}, {{ *args }}{% end %}
  end

  # :nodoc:
  # EventHandler macro magic
  macro finished
    \{% begin %}
      \{% for e in ::EventHandler::Event.subclasses %}
        \{% args = e.methods.find(&.name.==("initialize")).args.map(&.restriction) %}
        \{% event_name = e.name.identify.downcase.split('(').first.id %}
        \{% class_name = e.name.split('(').first.id %}

        private getter _event_\{{event_name}} = Array(Wrapper(Proc(\{{e.id}}, Bool))).new

        private def internal_insert(type : \{{e.id}}.class, wrapper : ::EventHandler::Wrapper(Proc(Event, Bool)))
          _event_\{{event_name}}.insert wrapper.at, wrapper
          _emit AddHandlerEvent, type, wrapper.unsafe_as(::EventHandler::Wrapper(Proc(::EventHandler::Event, Bool)))
          wrapper
        end
        private def internal_insert(type : \{{e.id}}.class, handler : Proc(\{{e.id}}, Bool), once : Bool, async : Bool, at : Int)
          wrapper = ::EventHandler::Wrapper(Proc(\{{e.id}}, Bool)).new handler, once, async, at
          internal_insert(type, wrapper)
        end

        # Adds *handler* to list of handlers for event *type*.
        def on(type : \{{e.id}}.class, handler : Proc(\{{e.id}}, Bool), once = false, async = ::EventHandler.async?, at = ::EventHandler.at_end)
          internal_insert type, handler, once, async, at
        end
        # :ditto:
        def on(type : \{{e.id}}.class, once = false, async = ::EventHandler.async?, at = ::EventHandler.at_end, &handler : \{{e.id}} -> Bool)
          on type, handler, once, async, at
        end
        # :ditto:
        def on(type : \{{e.id}}.class, wrapper : ::EventHandler::Wrapper(Proc(Event, Bool)))
          internal_insert type, wrapper
        end

        # Adds *handler* to list of handlers for event *type*.
        # After it triggers once, it is automatically removed.
        #
        # The same behavior is obtained using `on` and providing argument *once*.
        def once(type : \{{e.id}}.class, handler : Proc(\{{e.id}}, Bool), async = ::EventHandler.async?, at = ::EventHandler.at_end)
          on type, handler, true, async, at
        end
        # :ditto:
        def once(type : \{{e.id}}.class, async = ::EventHandler.async?, at = ::EventHandler.at_end, &handler : \{{e.id}} -> Bool)
          on type, handler, true, async, at
        end

        # Removes *handler* from list of handlers for event *type*.
        def off(type : \{{e.id}}.class, handler : Proc(\{{e.id}}, Bool))
          if wrapper = _event_\{{event_name}}.find {|h| h.handler == handler }
            off type, wrapper
          end
        end
        # :ditto:
        def off(type : \{{e.id}}.class, hash : UInt64)
          if wrapper = _event_\{{event_name}}.find {|h| h.handler_hash == hash }
            off type, wrapper
          end
        end
        # :ditto:
        def off(type : \{{e.id}}.class, wrapper : ::EventHandler::Wrapper(Proc(::EventHandler::Event, Bool)))
          if w = _event_\{{event_name}}.delete wrapper
           _emit RemoveHandlerEvent, type, wrapper.unsafe_as(::EventHandler::Wrapper(Proc(::EventHandler::Event, Bool)))
           w
          end
        end
        # :ditto:
        def off(type : \{{e.id}}.class, at : Int)
          off type, _event_\{{event_name}}[at]
        end

        # Removes all handlers for event *type*.
        #
        # If *emit* is false, `RemoveHandlerEvent`s are not emitted.
        #
        # If *emit* is true, `RemoveHandlerEvent`s is emitted once for every distinct `Wrapper` object removed.
        # See README for detailed description of this behavior.
        def remove_all_handlers(type : \{{e.id}}.class, emit = ::EventHandler.emit_on_remove_all?)
          if emit
            wrappers = _event_\{{event_name}}.uniq
            wrappers.each do |w|
              off type, w
            end
          else
            _event_\{{event_name}}.clear
          end
          true
        end

        # Returns list of handlers for event *type*.
        def handlers(type : \{{e.id}}.class)
          _event_\{{event_name}}
        end

        # Low-level function used to execute handlers and almost nothing else.
        # Regular users should use `#emit` instead.
        protected def _emit(type : \{{class_name}}.class, event : \{{class_name}}, async : Bool? = nil)
          if _event_\{{event_name}}.empty?
            if type == ::EventHandler::ExceptionEvent && event.is_a? ::EventHandler::ExceptionEvent
              raise event.exception
            end
          end

          ret = true

          # This loop invokes all registered handlers, and also removes
          # those which were intended to run only once.
          _event_\{{event_name}}.reject! do |handler|
            ret = ret && handler.call(event, async)
            if handler.once?
              off type, handler
            end
            handler.once?
          end

          ret
        end
        # :ditto:
        protected def _emit(type : \{{class_name}}.class, *args)
          _emit type, \{{e.id}}.new *args
        end

        # Emits event *type* with provided parameters.
        #
        # If all handlers run synchronously, returns Bool.
        # If any handler runs asynchronously, returns nil.
        def emit(type : \{{e.id}}.class, event : ::EventHandler::Event)
          _emit ::EventHandler::AnyEvent, \{{e.id}}, event

          if type == :screen
           return _emit(type, event)
          end

          if _emit(type, event) == false
            return false
          end

          true
        end
        # :ditto:
        def emit(type : \{{e.id}}.class, *args)
          event =  \{{e.id}}.new *args
          emit type, event
        end

      \{% end %}
    \{% end %}
  end
end
