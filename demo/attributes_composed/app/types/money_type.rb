# Attributes API glue: teaches Active Record how to move between the integer
# +price+ column (cents) and the Money value object.
#
#   class Product < ApplicationRecord
#     attribute :price, MoneyType.new
#   end
#
# The three hooks that matter:
#
#   cast(value)        # assignment: form params, Product.new(price: "12.50")
#   deserialize(value) # database -> Ruby
#   serialize(value)   # Ruby -> database (also used by `where(price: money)`)
class MoneyType < ActiveRecord::Type::Value
  def type
    :money
  end

  # ActiveModel::Type::Value#cast already returns nil for nil and delegates
  # everything else here.
  def cast_value(value)
    case value
    when Money   then value
    when Numeric then Money.from_amount(value)
    when String  then Money.parse(value) # nil when unparseable; see MoneyValidator
    end
  end

  # +value+ is normally an Integer, but a column default arrives as the string
  # "0" from the schema; Money#initialize coerces it.
  def deserialize(value)
    Money.new(cents: value) unless value.nil?
  end

  def serialize(value)
    case value
    when Money then value.cents
    when nil   then nil
    else            cast(value)&.cents
    end
  end
end
