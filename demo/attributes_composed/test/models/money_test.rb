require "test_helper"

class MoneyTest < ActiveSupport::TestCase
  test "parses form-style input" do
    assert_equal Money.new(cents: 1250), Money.parse("12.50")
    assert_equal Money.new(cents: 1250), Money.parse("12.5")
    assert_equal Money.new(cents: 123_456), Money.parse(" $1,234.56 ")
    assert_equal Money.new(cents: -300), Money.parse("-3")
  end

  test "refuses input that isn't an amount" do
    assert_nil Money.parse("abc")
    assert_nil Money.parse("12.345")
    assert_nil Money.parse("")
  end

  test "renders a plain decimal string for forms" do
    assert_equal "12.50", Money.new(cents: 1250).to_s
    assert_equal "0.05", Money.new(cents: 5).to_s
    assert_equal "-3.00", Money.new(cents: -300).to_s
  end

  test "is comparable and immutable" do
    assert Money.new(cents: 100) < Money.new(cents: 200)
    assert_equal Money.new(cents: 300), Money.new(cents: 100) + Money.new(cents: 200)
    assert_predicate Money.new(cents: 100), :frozen?
  end
end
