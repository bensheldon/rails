# frozen_string_literal: true

# :markup: markdown
# This class is inherited by the has_one and belongs_to association classes

module ActiveRecord::Associations::Builder # :nodoc:
  class SingularAssociation < Association # :nodoc:
    def self.valid_options(options)
      super + [:required, :touch]
    end

    def self.define_accessors(owner, reflection)
      super
      name = reflection.name

      define_constructors(owner, name) unless reflection.polymorphic?

      define_association_method(owner, "reload_#{name}", name, "force_reload_reader")
      define_association_method(owner, "reset_#{name}", name, "reset")
    end

    # Defines the (build|create)\_association methods for belongs_to or has_one association
    def self.define_constructors(owner, name)
      define_association_method(owner, "build_#{name}", name, "build(*args, &block)", params: "*args, &block")
      define_association_method(owner, "create_#{name}", name, "create(*args, &block)", params: "*args, &block")
      define_association_method(owner, "create_#{name}!", name, "create!(*args, &block)", params: "*args, &block")
    end

    def self.define_callbacks(model, reflection)
      super

      # If the record is saved or destroyed and `:touch` is set, the parent
      # record gets a timestamp updated. We want to know about it, because
      # deleting the association would change that side-effect and perhaps there
      # is code relying on it.
      if reflection.deprecated? && reflection.options[:touch]
        model.before_save do
          report_deprecated_association(reflection, context: ":touch has a side effect here")
        end

        model.before_destroy do
          report_deprecated_association(reflection, context: ":touch has a side effect here")
        end
      end
    end

    private_class_method :valid_options, :define_accessors, :define_constructors
  end
end
