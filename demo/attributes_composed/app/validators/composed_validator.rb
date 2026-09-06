# Validates a +composed_of+ value object that validates itself (it includes
# ActiveModel::Validations) and copies its errors onto the owning record.
#
#   validates :address,    composed: true                    # keys: "address.street"
#   validates :dimensions, composed: { errors_on: :columns } # keys: "width_cm"
#
# +errors_on: :nested+ (the default) imports each error under a nested key,
# "address.street", exactly like +accepts_nested_attributes_for+ does. Pair it
# with +fields_for+ in the form: the nested builder's object is the value
# object itself, which still carries its own errors, so +field_with_errors+
# wrapping and inline messages work with no extra plumbing.
#
# +errors_on: :columns+ re-keys each error to the database column it maps to,
# using the +composed_of+ reflection's mapping. Pair it with plain form fields
# bound to the columns.
#
# Either way, errors the value object adds to +:base+ (cross-field rules) land
# on the composed attribute itself (+:address+ / +:dimensions+).
#
# A +nil+ value object is not an error here; use +presence: true+ for that.
class ComposedValidator < ActiveModel::EachValidator
  ERRORS_ON = [ :nested, :columns ].freeze

  def check_validity!
    unless ERRORS_ON.include?(errors_on)
      raise ArgumentError, ":errors_on must be one of #{ERRORS_ON.inspect}, got #{errors_on.inspect}"
    end
  end

  def validate_each(record, attribute, value)
    return if value.nil? || value.valid?

    columns = column_mapping(record.class, attribute) if errors_on == :columns

    value.errors.each do |error|
      record.errors.import(error, attribute: target_attribute(attribute, error, columns))
    end
  end

  private
    def errors_on
      options.fetch(:errors_on, :nested)
    end

    def target_attribute(attribute, error, columns)
      if error.attribute == :base
        attribute
      elsif columns
        columns.fetch(error.attribute.to_s) { :"#{attribute}.#{error.attribute}" }
      else
        :"#{attribute}.#{error.attribute}"
      end
    end

    # { "street" => :address_street, ... } from the composed_of declaration.
    def column_mapping(klass, attribute)
      reflection = klass.reflect_on_aggregation(attribute)
      raise ArgumentError, "#{klass} has no composed_of :#{attribute}" unless reflection

      reflection.mapping.to_h { |column, part| [ part.to_s, column.to_sym ] }
    end
end
