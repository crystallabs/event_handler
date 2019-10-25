module Crysterm
  module EventEmitter

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
         emit NewListenerEvent, type, ->(ev : Event){ handler.call(ev.as({{e.id}})) }
        end

        def on(type : {{e.id}}.class, handler : Proc({{e.id}}, Bool))
          internal_add type, handler, false
        end
        def on(type : {{e.id}}.class, &block : {{e.id}} -> Bool)
          on type, block
        end

        def once(type : {{e.id}}.class, handler : Proc({{e.id}}, Bool))
          internal_add type, handler, true
        end
        def once(type : {{e.id}}.class, &block : {{e.id}} -> Bool)
          once type, block
        end
        def once(*arg) add_once(*arg) end

        def off(type : {{e.id}}.class, handler : Proc({{e.id}}, Bool))
          if _event_{{event_name}}.delete Handler.new handler
           emit RemoveListenerEvent, type, ->(ev : Event){ handler.call(ev.as({{e.id}})) }
          end
        end

        def removeAllListeners
          # Blessed does it this way by just emptying the handlers, without emitting any RemoveListenerEvents
          _event_{{event_name}}.clear
        end

        def listeners(type : {{e.id}}.class)
          _event_{{event_name}}
        end

        def _emit(type : {{class_name}}.class, obj : {{class_name}})
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
        def _emit(type : {{class_name}}.class, *args)
          emit type, {{e.id}}.new *args
        end

        def emit(type : {{e.id}}.class, *args)
         #emit EventEvent, type, ->(ev : Event){ handler.call(ev.as({{e.id}})) }

          # TODO - enable when Node is added
          #if @type == :screen
          # return _emit(type, *args)
          #end

          if _emit(type, *args) == false
            return false
          end

          # TODO
          # Add "Element..." events

          true
        end
      {% end %}
    {% end %}
  end
end
