# Shared behaviour for the immutable, self-validating value objects that are
# attached to Product through +composed_of+ (see Address and Dimensions).
#
# * ActiveModel::Model gives us +validates+/+errors+, a hash constructor, and
#   +model_name+ (used by +fields_for+ and by i18n lookups).
# * ActiveModel::Attributes gives typed, cast attributes and an +attributes+
#   hash we can use for value equality.
#
# +composed_of+ freezes every value object it hands out. That is fine:
# ActiveModel::Validations#freeze pre-initialises the errors object, so a
# frozen value object can still run +valid?+ and report errors.
module ValueObject
  extend ActiveSupport::Concern

  include ActiveModel::Model
  include ActiveModel::Attributes

  class_methods do
    # Used as the +composed_of+ +:converter+. Accepts anything hash-like,
    # including permitted ActionController::Parameters from +fields_for+.
    #
    # Returns +nil+ when every value is blank so that, together with
    # +allow_nil: true+, submitting an empty fieldset clears the mapped
    # columns instead of persisting empty strings.
    def build(attributes)
      attributes = attributes.to_h if attributes.respond_to?(:permitted?)
      return nil if attributes.values.all?(&:blank?)

      new(attributes)
    end
  end

  # Value objects are equal when they are the same kind of thing with the same parts.
  def ==(other)
    other.instance_of?(self.class) && attributes == other.attributes
  end
  alias eql? ==

  def hash
    [ self.class, attributes ].hash
  end

  # Object#blank? delegates to +empty?+ when it is defined, so an all-blank
  # value object counts as blank for +validates ..., presence: true+.
  def empty?
    attributes.each_value.all?(&:blank?)
  end

  def inspect
    parts = attributes.map { |name, value| "#{name}=#{value.inspect}" }
    "#<#{self.class.name} #{parts.join(' ')}>"
  end
end
