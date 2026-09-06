class Product < ApplicationRecord
  # ── Attributes API: ONE column ⇄ one compact object ──────────────────────
  #
  # +price+ is an integer column holding cents. MoneyType casts what comes in
  # ("12.50" from a form, 12.5, a Money) and what comes out of the database
  # (1250) into a Money value object. Column name and attribute name are the
  # same; the Attributes API only changes the type.
  attribute :price, MoneyType.new

  # ── composed_of: SEVERAL columns ⇄ one compact object ────────────────────
  #
  # +mapping+ pairs each column with an attribute of the value object, in the
  # order the +constructor+ receives them. +converter+ runs when something that
  # isn't already an Address is assigned, e.g. the hash that +fields_for+
  # posts. +allow_nil+ lets an all-nil set of columns read back as +nil+ and
  # lets a +nil+ (or all-blank) assignment clear the columns.
  composed_of :address,
    mapping: { address_street: :street, address_city: :city, address_postal_code: :postal_code },
    allow_nil: true,
    constructor: ->(street, city, postal_code) { Address.new(street:, city:, postal_code:) },
    converter: ->(attributes) { Address.build(attributes) }

  composed_of :dimensions,
    mapping: { width_cm: :width, height_cm: :height, depth_cm: :depth },
    allow_nil: true,
    constructor: ->(width, height, depth) { Dimensions.new(width:, height:, depth:) },
    converter: ->(attributes) { Dimensions.build(attributes) }

  # ── Validations ──────────────────────────────────────────────────────────
  validates :name, presence: true

  # Attributes API: a plain EachValidator that knows how to read the raw input,
  # so "abc" is "not a valid amount" rather than "blank". It owns the blank
  # check as well; pass +allow_blank: true+ to make the price optional.
  validates :price, money: true

  # composed_of, style 1: Address validates itself, errors are imported under
  # nested keys ("address.street"). The form uses +fields_for :address+.
  validates :address, presence: true, composed: true

  # composed_of, style 2: Dimensions validates itself, errors are re-keyed to
  # the underlying columns ("width_cm"). The form binds fields to the columns.
  # Dimensions are optional, so no +presence+ here.
  validates :dimensions, composed: { errors_on: :columns }
end
