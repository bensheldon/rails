# A value object spread across THREE columns (address_street, address_city,
# address_postal_code) and attached to Product with +composed_of+.
#
# Address validates itself. Product then imports those errors under nested
# keys such as "address.street" (see ComposedValidator), which is the same
# shape +accepts_nested_attributes_for+ produces and pairs with +fields_for+.
class Address
  include ValueObject

  attribute :street, :string
  attribute :city, :string
  attribute :postal_code, :string

  validates :street, :city, presence: true
  validates :postal_code, presence: true,
                          format: { with: /\A\d{5}(?:-\d{4})?\z/, allow_blank: true, message: "must be a ZIP code like 12345 or 12345-6789" }

  def to_s
    [ street, [ city, postal_code ].compact_blank.join(" ") ].compact_blank.join(", ")
  end
end
