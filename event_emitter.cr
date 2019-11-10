module Crysterm
  # Implementation of Crysterm's event system, and the functional core of Crysterm.
  # The first low-level class build on `EventEmitter` is `Node`, and everything else inherits from `Node`.
  module EventEmitter

    ASYNC = false

    # Record for easy and convenient creation of handler procs.
    #
    # If *once* is true, handler will be automatically removed after it is invoked once.
    #
    # ```
    # c = SomeClass.new
    # handler = ClickedEvent::Handler.new { |e| p "Coordinates are x=#{e.x} y=#{e.y}"; true }
    # c.on ClickedEvent, handler
    # ```
    class Handler(T)
      getter  handler : T
      getter  handler_hash : UInt64
      getter? once : Bool
      getter? async : Bool
      getter  at : Int32
      def initialize(@handler : T, @once, @async, @at)
        @handler_hash = @handler.hash
      end
      def call(obj, async)
        async = @async if async.nil?
        if async
          spawn do @handler.call obj end
          nil
        else
          @handler.call obj
        end
      end
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

        private def internal_insert(type : {{e.id}}.class, handler : Proc({{e.id}}, Bool), once : Bool, async : Bool, at : Int)
          handler_obj = Handler(Proc({{e.id}}, Bool)).new handler, once, async, at
          _event_{{event_name}}.insert at, handler_obj
          _emit AddHandlerEvent, type, handler_obj.unsafe_as(EventEmitter::Handler(Proc(Event, Bool)))
        end

        # Installs *handler* as a handler for event of type *type*.
        def on(type : {{e.id}}.class, handler : Proc({{e.id}}, Bool), once = false, async = ASYNC, at = -1)
          internal_insert type, handler, once, async, at
        end
        # :ditto:
        def on(type : {{e.id}}.class, once = false, async = ASYNC, at = -1, &handler : {{e.id}} -> Bool)
          on type, handler, once, async, at
        end

        # Installs *handler* as a handler for event of type *type*.
        # It triggers it at most once, after which the handler is automatically removed.
        def once(type : {{e.id}}.class, handler : Proc({{e.id}}, Bool), async = ASYNC, at = -1)
          on type, handler, true, async, at
        end
        # :ditto:
        def once(type : {{e.id}}.class, async = ASYNC, at = -1, &handler : {{e.id}} -> Bool)
          on type, handler, true, async, at
        end

        # Uninstalls *handler* as a handler for event of type *type*.
        def off(type : {{e.id}}.class, handler : Proc({{e.id}}, Bool))
          if handler_obj = _event_{{event_name}}.find {|h| h.handler == handler }
            off type, handler_obj
          end
        end
        # :ditto:
        def off(type : {{e.id}}.class, hash : UInt64)
          if handler_obj = _event_{{event_name}}.find {|h| h.handler_hash == hash }
            off type, handler_obj
          end
        end
        # :ditto:
        def off(type : {{e.id}}.class, handler : EventEmitter::Handler(Proc(Event, Bool)))
          if _event_{{event_name}}.delete handler
           _emit RemoveHandlerEvent, type, handler.unsafe_as(EventEmitter::Handler(Proc(Event, Bool)))
          end
        end

        # Removes all handlers for *type*.
        # The removal is immediate, and no `RemoveHandlerEvent` events are emitted.
        def remove_all_handlers(type : {{e.id}}.class)
          _event_{{event_name}}.clear
        end

        # Returns array of currently installed handlers for *type*.
        def handlers(type : {{e.id}}.class)
          _event_{{event_name}}
        end

        # Low-level function used to execute handlers and almost nothing else.
        # Regular users should use `#emit` instead.
        protected def _emit(type : {{class_name}}.class, obj : {{class_name}}, async : Bool? = nil)
          if _event_{{event_name}}.empty?
            if type == ExceptionEvent && obj.is_a? ExceptionEvent
              raise obj.exception
            end
          end

          ret = true

          # This loop invokes all registered handlers, and also removes
          # those which were intended to run only once.
          _event_{{event_name}}.reject! do |handler|
            ret = ret && handler.call(obj, async)
            if handler.once?
              off type, handler
            end
            handler.once?
          end

          ret
        end
        # :ditto:
        protected def _emit(type : {{class_name}}.class, *args)
          _emit type, {{e.id}}.new *args
        end

        # Emits event *type*, along with supplied parameters.
        def emit(type : {{e.id}}.class, obj : Event)
          _emit AnyEvent, {{e.id}}, obj

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
