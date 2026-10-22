# frozen_string_literal: true

# :markup: markdown
require "active_record/associations"

module ActiveRecord::Associations::Builder # :nodoc:
  class CollectionAssociation < Association # :nodoc:
    CALLBACKS = [:before_add, :after_add, :before_remove, :after_remove].freeze

    def self.valid_options(options)
      super + [:class_name, :before_add, :after_add, :before_remove, :after_remove, :extend]
    end

    def self.define_callbacks(model, reflection)
      super
      name    = reflection.name
      options = reflection.options
      CALLBACKS.each { |callback_name|
        define_callback(model, callback_name, name, options)
      }
    end

    def self.define_extensions(model, name, &block)
      if block_given?
        extension_module_name = "#{name.to_s.camelize}AssociationExtension"
        extension = Module.new(&block)
        model.const_set(extension_module_name, extension)
      end
    end

    def self.define_callback(model, callback_name, name, options)
      full_callback_name = "#{callback_name}_for_#{name}"

      callback_values = Array(options[callback_name.to_sym])
      method_defined = model.respond_to?(full_callback_name)

      # If there are no callbacks, we must also check if a superclass had
      # previously defined this association
      return if callback_values.empty? && !method_defined

      unless method_defined
        model.class_attribute(full_callback_name, instance_accessor: false, instance_predicate: false)
      end

      callbacks = callback_values.map do |callback|
        case callback
        when Symbol
          ->(method, owner, record) { owner.send(callback, record) }
        when Proc
          ->(method, owner, record) { callback.call(owner, record) }
        else
          ->(method, owner, record) { callback.send(method, owner, record) }
        end
      end
      model.send "#{full_callback_name}=", callbacks
    end

    # Defines the setter and getter methods for the collection_singular_ids.
    def self.define_readers(owner, name)
      super

      # The method name depends on inflections, so key the shared body by
      # the association name instead.
      define_association_method(owner, "#{name.to_s.singularize}_ids", name, "ids_reader",
        namespace: :active_record_association_ids, canonical_name: name)
    end

    def self.define_writers(owner, name)
      super

      define_association_method(owner, "#{name.to_s.singularize}_ids=", name, "ids_writer(ids)", params: "ids",
        namespace: :active_record_association_ids, canonical_name: "#{name}=")
    end

    private_class_method :valid_options, :define_callback, :define_extensions, :define_readers, :define_writers
  end
end
