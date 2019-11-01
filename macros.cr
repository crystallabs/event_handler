# A copy of Crystal's 0.31.1 macro, modified to create a class instead of a struct.
# This comes handy primarily when defining events in a single line, like one would do with the usual 'record' macro.
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

# And this one is a shorthand for creating events.
macro event(e, *args)
  class_record {{e.id}} < ::Crysterm::Event{% if args.size > 0 %}, {{ *args }}{% end %}
  class_record {{e.id}}::Element < ::Crysterm::Event, event : {{e.id}}
end

# Defines new_method as an alias of old_method.
#
# This creates a new method new_method that invokes old_method.
#
# Note that due to current language limitations this is only useful
# when neither named arguments nor blocks are involved.
#
# ```
# class Person
#   getter name
#
#   def initialize(@name)
#   end
#
#   alias_method full_name, name
# end
#
# person = Person.new "John"
# person.name #=> "John"
# person.full_name #=> "John"
# ```
#
# This macro was present in Crystal until commit 7c3239ee505e07544ec372839efed527801d210a.
macro alias_method(new_method, old_method)
  def {{new_method.id}}(*args)
    {{old_method.id}}(*args)
  end
end

# Defines new_method as an alias of last (most recently defined) method.
macro alias_previous(*new_methods)
  {% for new_method in new_methods %}
    alias_method new_method, {{@type.methods.last.name}}
  {% end %}
end
