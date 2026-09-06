# Validates a Money attribute defined through the Attributes API.
#
#   validates :price, money: true                          # required, >= 0
#   validates :price, money: { allow_blank: true }         # optional
#   validates :price, money: { allow_negative: true }
#
# When MoneyType can't parse the input, the cast value is +nil+, which a
# separate +presence: true+ would report as "can't be blank" for "abc". So this
# validator owns the blank check too: like Rails' own NumericalityValidator, it
# looks at what the user actually typed (+price_before_type_cast+) and reports
# "is not a valid amount" for garbage and "can't be blank" for nothing.
class MoneyValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    if value.nil?
      raw = raw_value(record, attribute)

      if raw.present?
        record.errors.add(attribute, :not_an_amount, value: raw)
      elsif !options[:allow_blank]
        record.errors.add(attribute, :blank)
      end
    elsif value.negative? && !options[:allow_negative]
      record.errors.add(attribute, :negative_amount)
    end
  end

  private
    # Only consult the raw value when it was assigned by the user (as opposed to
    # loaded from the database), mirroring NumericalityValidator.
    def raw_value(record, attribute)
      came_from_user = :"#{attribute}_came_from_user?"
      return if record.respond_to?(came_from_user) && !record.public_send(came_from_user)

      before_type_cast = :"#{attribute}_before_type_cast"
      record.public_send(before_type_cast) if record.respond_to?(before_type_cast)
    end
end
