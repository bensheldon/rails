Product.destroy_all

Product.create!(
  name: "Standing desk",
  price: "649.00",                                   # cast by MoneyType
  address: { street: "1 Market St", city: "San Francisco", postal_code: "94105" }, # converted to an Address
  width_cm: 120, height_cm: 60, depth_cm: 8           # read back as a Dimensions
)

Product.create!(
  name: "Desk lamp",
  price: Money.from_amount(39.5),
  address: Address.new(street: "500 W Madison St", city: "Chicago", postal_code: "60661"),
  dimensions: Dimensions.new(width: 15, height: 45, depth: 15)
)

Product.create!(
  name: "Gift card",
  price: 25,
  address: Address.new(street: "1 Infinite Loop", city: "Cupertino", postal_code: "95014")
  # no dimensions: all three columns stay NULL and `dimensions` reads back as nil
)
