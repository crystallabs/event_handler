module Crysterm
  # Implementation of Crysterm's event system, and the functional core of Crysterm.
  # The first low-level class build on `EventEmitter` is `Node`, and everything else inherits from `Node`.
  module EventEmitter

    # Record for easy and convenient creation of handler procs.
    #
    # If *run_once* is true, handler will be automatically removed after it is invoked once.
    #
    # ```
    # c = SomeClass.new
    # handler = ClickedEvent::Handler.new { |e| p "Coordinates are x=#{e.x} y=#{e.y}"; true }
    # c.on ClickedEvent, handler
    # ```
    record Handler(T), handler : T, run_once : Bool = false do
      delegate :call, to: @handler
    end

    {% begin %}
      {% for e in Event.subclasses %}
        {% args = e.methods.find(&.name.==("initialize")).args.map(&.restriction) %}
        {% event_name = e.name.identify.downcase.split('(').first.id %}
        {% class_name = e.name.split('(').first.id %}

        def {{e.id}}.element
          {{e.id}}::Element
        end

        private getter _event_{{event_name}} = Array(Handler(Proc({{e.id}}, Bool))).new

        private def internal_insert(at : Int, type : {{e.id}}.class, handler : Proc({{e.id}}, Bool), once : Bool)
         _event_{{event_name}}.insert at, Handler(Proc({{e.id}}, Bool)).new handler, once
         _emit NewHandlerEvent, type, ->(ev : Event){ handler.call(ev.as({{e.id}})) }
        end

        # Installs *handler* as a handler for event of type *type*.
        def on(type : {{e.id}}.class, handler : Proc({{e.id}}, Bool))
        #def on(type : {{e.id}}.class, handler : Proc({{e.id}}, Bool)), at = -1)
          at = -1
          internal_insert at, type, handler, false
        end
        # :ditto:
        def on(type : {{e.id}}.class, &handler : {{e.id}} -> Bool)
        #def on(type : {{e.id}}.class, at = -1, &handler : {{e.id}} -> Bool)
          on type, handler
        end

        # Installs *handler* as a handler for event of type *type*.
        # It triggers it at most once, after which the handler is automatically removed.
        def once(type : {{e.id}}.class, handler : Proc({{e.id}}, Bool))
        #def once(type : {{e.id}}.class, handler : Proc({{e.id}}, Bool), at = -1)
          at = -1
          internal_insert at, type, handler, true
        end
        # :ditto:
        def once(type : {{e.id}}.class, &handler : {{e.id}} -> Bool)
        #def once(type : {{e.id}}.class, at = -1, &handler : {{e.id}} -> Bool)
          once type, handler
        end

        # Uninstalls *handler* as a handler for event of type *type*.
        def off(type : {{e.id}}.class, handler : Proc({{e.id}}, Bool))
          if _event_{{event_name}}.delete Handler.new handler
           _emit RemoveHandlerEvent, type, ->(ev : Event){ handler.call(ev.as({{e.id}})) }
          end
        end

        # Removes all handlers for *type*.
        # The removal is immediate, and no `RemoveHandlerEvent` events are emitted.
        def remove_all_handlers(type : {{e.id}}.class)
          # Blessed does it this way by just emptying the handlers, without emitting any RemoveHandlerEvents
          _event_{{event_name}}.clear
        end

        # Returns array of currently installed handlers for *type*.
        def handlers(type : {{e.id}}.class)
          _event_{{event_name}}
        end

        # Low-level function used to execute handlers and almost nothing else.
        # Regular users should use `#emit` instead.
        protected def _emit(type : {{class_name}}.class, obj : {{class_name}})
          if _event_{{event_name}}.empty?
            if type == ExceptionEvent && obj.is_a? ExceptionEvent
              raise obj.exception
            end
          end

          ret = nil
          _event_{{event_name}}.reject! do |handler|
            ret = false if handler.call(obj) == false
            handler.run_once
          end

          ret != false
        end
        # :ditto:
        protected def _emit(type : {{class_name}}.class, *args)
          _emit type, {{e.id}}.new *args
        end

        # Emits event *type*, along with supplied parameters.
        def emit(type : {{e.id}}.class, obj : Event)
          _emit EventEvent, {{e.id}}, obj

          if type == :screen
           return _emit(type, obj)
          end

          if _emit(type, obj) == false
            return false
          end

          true
        end
        # :ditto:
        def emit(type : {{e.id}}.class, *args)
          obj =  {{e.id}}.new *args
          emit type, obj
        end

      {% end %}
    {% end %}
  end
end
