require "test_helper"

class ProductTest < ActiveSupport::TestCase
  setup do
    @desk = products(:desk)
  end

  # ── Attributes API: Money in one column ───────────────────────────────────

  test "price reads back from the database as Money" do
    assert_equal Money.new(cents: 64_900), @desk.price
    assert_equal 64_900, @desk.read_attribute_before_type_cast(:price)
  end

  test "a new product gets the column default as Money, not as the schema's string" do
    price = Product.new.price

    assert_equal Money.zero, price
    assert_kind_of Integer, price.cents
  end

  test "price casts strings, numbers and Money on assignment" do
    product = Product.new

    product.price = "12.50"
    assert_equal Money.new(cents: 1250), product.price

    product.price = 12.5
    assert_equal Money.new(cents: 1250), product.price

    product.price = Money.new(cents: 99)
    assert_equal Money.new(cents: 99), product.price
  end

  test "price serializes to cents and can be queried with a Money" do
    @desk.update!(price: "650")
    assert_equal 65_000, @desk.reload.read_attribute_before_type_cast(:price)
    assert_equal [ @desk ], Product.where(price: Money.from_amount(650)).to_a
  end

  test "unparseable price keeps the raw input and fails validation with a specific message" do
    @desk.price = "abc"

    assert_nil @desk.price
    assert_equal "abc", @desk.price_before_type_cast
    assert_not @desk.valid?
    assert_equal [ "is not a valid amount (got abc)" ], @desk.errors.messages_for(:price)
    assert_empty @desk.errors.where(:price, :blank), "presence should not also fire for bad input"
  end

  test "blank price and negative price are money errors" do
    @desk.price = ""
    assert_not @desk.valid?
    assert_equal [ "can't be blank" ], @desk.errors.messages_for(:price)

    @desk.price = "-1"
    assert_not @desk.valid?
    assert_equal [ "can't be negative" ], @desk.errors.messages_for(:price)
  end

  # ── composed_of: Address across three columns, nested errors ──────────────

  test "address reads back from the columns as a frozen Address" do
    address = @desk.address

    assert_equal Address.new(street: "1 Market St", city: "San Francisco", postal_code: "94105"), address
    assert_predicate address, :frozen?
    assert_raises(FrozenError) { address.street = "somewhere else" }
  end

  test "assigning an Address writes the mapped columns" do
    @desk.address = Address.new(street: "500 W Madison St", city: "Chicago", postal_code: "60661")

    assert_equal "500 W Madison St", @desk.address_street
    assert_equal "Chicago", @desk.address_city
    assert_equal "60661", @desk.address_postal_code
    assert @desk.address_city_changed?
  end

  test "assigning a hash (as fields_for posts) goes through the converter" do
    @desk.address = { "street" => "500 W Madison St", "city" => "Chicago", "postal_code" => "60661" }

    assert_equal Address.new(street: "500 W Madison St", city: "Chicago", postal_code: "60661"), @desk.address
  end

  test "assigning an all-blank hash clears the columns because the converter returns nil" do
    @desk.address = { street: "", city: "", postal_code: "" }

    assert_nil @desk.address
    assert_nil @desk.address_street
    assert_not @desk.valid?
    assert_equal [ "can't be blank" ], @desk.errors.messages_for(:address)
  end

  test "an invalid Address surfaces its errors on the product under nested keys" do
    @desk.address = { street: "", city: "Chicago", postal_code: "nope" }

    assert_not @desk.valid?
    assert_equal [ "can't be blank" ], @desk.errors.messages_for(:"address.street")
    assert_equal [ "must be a ZIP code like 12345 or 12345-6789" ], @desk.errors.messages_for(:"address.postal_code")
    assert_includes @desk.errors.full_messages, "Address street can't be blank"

    # The value object itself still carries its errors, which is what lets
    # fields_for render field-level errors for it.
    assert_equal [ "can't be blank" ], @desk.address.errors.messages_for(:street)
  end

  test "products can be found by an Address value object" do
    address = Address.new(street: "1 Market St", city: "San Francisco", postal_code: "94105")

    assert_equal [ @desk ], Product.where(address: address).to_a
  end

  # ── composed_of: Dimensions across three columns, errors on columns ───────

  test "dimensions read back as a Dimensions and nil when every column is NULL" do
    assert_equal Dimensions.new(width: 120, height: 60, depth: 8), @desk.dimensions
    assert_nil products(:gift_card).dimensions
  end

  test "a partially blank Dimensions puts errors on the mapped columns" do
    @desk.assign_attributes(width_cm: "", height_cm: "-5", depth_cm: "80")

    assert_not @desk.valid?
    assert_equal [ "can't be blank" ], @desk.errors.messages_for(:width_cm)
    assert_equal [ "must be greater than 0" ], @desk.errors.messages_for(:height_cm)
    assert_empty @desk.errors.messages_for(:depth_cm)
    assert_includes @desk.errors.full_messages, "Width can't be blank"
  end

  test "a cross-field Dimensions rule lands on the composed attribute" do
    @desk.assign_attributes(width_cm: 200, height_cm: 200, depth_cm: 200)

    assert_not @desk.valid?
    assert_equal [ "are too large to ship: length plus girth is 1000 cm, the limit is 300 cm" ],
      @desk.errors.messages_for(:dimensions)
  end

  test "leaving all dimension columns blank means no dimensions and no errors" do
    @desk.assign_attributes(width_cm: "", height_cm: "", depth_cm: "")

    assert @desk.valid?
    assert_nil @desk.dimensions
  end

  # ── Gotcha worth knowing ──────────────────────────────────────────────────

  test "composed_of caches the value object: direct column writes are not reflected until reload" do
    assert_equal "San Francisco", @desk.address.city # populates the aggregation cache

    @desk.address_city = "Oakland"
    assert_equal "San Francisco", @desk.address.city, "stale: the cached Address was built before the column changed"

    @desk.save!
    assert_equal "Oakland", @desk.reload.address.city

    # Assigning through the writer keeps the cache and the columns in sync.
    @desk.address = @desk.address.dup.tap { |a| a.city = "Berkeley" }
    assert_equal "Berkeley", @desk.address.city
    assert_equal "Berkeley", @desk.address_city
  end
end
