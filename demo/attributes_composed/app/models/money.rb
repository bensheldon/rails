# A compact value object that lives in ONE integer column (cents).
#
# Money knows nothing about Active Record. MoneyType (app/types/money_type.rb)
# is what connects it to the +price+ column through the Attributes API.
Money = Data.define(:cents) do
  include Comparable

  AMOUNT_PATTERN = /\A-?\d+(?:\.\d{1,2})?\z/

  # Always hold an Integer. Column defaults come out of the schema as strings
  # ("0"), and MoneyType#deserialize hands them straight to us.
  def initialize(cents:)
    super(cents: Integer(cents))
  end

  # Parses user input such as "12", "12.5", "$1,234.56" or " -3.00 ".
  # Returns +nil+ when the input isn't an amount; MoneyValidator turns that
  # into a validation error instead of silently storing 0.
  def self.parse(string)
    cleaned = string.to_s.strip.delete("$,")
    return nil unless cleaned.match?(AMOUNT_PATTERN)

    from_amount(BigDecimal(cleaned))
  end

  # 12.5 means $12.50, not 12 cents.
  def self.from_amount(amount)
    new(cents: (BigDecimal(amount.to_s) * 100).round.to_i)
  end

  def self.zero
    new(cents: 0)
  end

  def amount
    BigDecimal(cents) / 100
  end

  def <=>(other)
    cents <=> other.cents if other.is_a?(Money)
  end

  def +(other) = with(cents: cents + other.cents)
  def -(other) = with(cents: cents - other.cents)

  def zero?     = cents.zero?
  def negative? = cents.negative?

  # A plain "12.50" so the value round-trips through a text field. Views use
  # +number_to_currency(money.amount)+ for display.
  def to_s
    whole, fraction = cents.abs.divmod(100)
    "#{'-' if cents.negative?}#{whole}.#{fraction.to_s.rjust(2, '0')}"
  end
end
