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

        private getter _event_{{event_name}} = Array(Handler(Proc({{e.id}}, Bool))).new

        private def internal_add(type : {{e.id}}.class, handler : Proc({{e.id}}, Bool), once : Bool)
         _event_{{event_name}} << Handler(Proc({{e.id}}, Bool)).new handler, once
         _emit NewListenerEvent, type, ->(ev : Event){ handler.call(ev.as({{e.id}})) }
        end

        # Installs *handler* as a handler for event of type *type*.
        def on(type : {{e.id}}.class, handler : Proc({{e.id}}, Bool))
          internal_add type, handler, false
        end
        # ditto
        def on(type : {{e.id}}.class, &handler : {{e.id}} -> Bool)
          on type, handler
        end

        # Installs *handler* as a handler for event of type *type*.
        # It triggers it at most once, after which the handler is automatically removed.
        def once(type : {{e.id}}.class, handler : Proc({{e.id}}, Bool))
          internal_add type, handler, true
        end
        # ditto
        def once(type : {{e.id}}.class, &handler : {{e.id}} -> Bool)
          once type, handler
        end

        # Uninstalls *handler* as a handler for event of type *type*.
        def off(type : {{e.id}}.class, handler : Proc({{e.id}}, Bool))
          if _event_{{event_name}}.delete Handler.new handler
           _emit RemoveListenerEvent, type, ->(ev : Event){ handler.call(ev.as({{e.id}})) }
          end
        end

        # Removes all handlers for *type*.
        # The removal is immediate, and no `RemoveListenerEvent` events are emitted.
        def removeAllListeners(type : {{e.id}}.class)
          # Blessed does it this way by just emptying the handlers, without emitting any RemoveListenerEvents
          _event_{{event_name}}.clear
        end

        # Returns array of currently installed handlers for *type*.
        def listeners(type : {{e.id}}.class)
          _event_{{event_name}}
        end

        # Low-level function used to execute handlers and almost nothing else.
        # Regular users should use `#emit` instead.
        private def _emit(type : {{class_name}}.class, obj : {{class_name}})
          if _event_{{event_name}}.empty?
            if type == ErrorEvent
              raise Exception.new obj.to_s
            end
          end

          ret = nil
          _event_{{event_name}}.reject! do |handler|
            ret = false if handler.call(obj) == false
            handler.run_once
          end

          ret != false
        end
        # ditto
        private def _emit(type : {{class_name}}.class, *args)
          _emit type, {{e.id}}.new *args
        end

        # Emits event *type*, along with supplied parameters.
        def emit(type : {{e.id}}.class, obj : Event)
          _emit EventEvent, {{e.id}}, obj

          # TODO - enable when Node is added
          #if @type == :screen
          # return _emit type, *args
          #end

          if _emit(type, obj) == false
            return false
          end

          # TODO
          # Add "Element..." events

          true
        end
        # ditto
        def emit(type : {{e.id}}.class, *args)
          obj =  {{e.id}}.new *args
          emit type, obj
        end
      {% end %}
    {% end %}
  end
end
