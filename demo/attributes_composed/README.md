# Attributes API & `composed_of` demo

A small, runnable Rails app (generated with `rails new --dev` against the
Rails checkout two directories up) that shows two ways of attaching compact
value objects to an Active Record model, and how to validate them and show
the errors in a form.

| Value object | Columns | Mechanism | Where its errors land on `Product` | Form style |
| --- | --- | --- | --- | --- |
| `Money` | `price` (integer cents) | Attributes API: `attribute :price, MoneyType.new` | `:price` | plain field |
| `Address` | `address_street`, `address_city`, `address_postal_code` | `composed_of :address` | nested keys: `address.street` | `fields_for :address` |
| `Dimensions` | `width_cm`, `height_cm`, `depth_cm` | `composed_of :dimensions` | the columns: `width_cm`; cross-field rule on `:dimensions` | plain fields on the columns |

## Running it

```sh
cd demo/attributes_composed
bundle install
bin/rails db:prepare db:seed
bin/rails server
bin/rails test
```

Then open http://localhost:3000, edit a product, and submit junk: `abc` for the
price, an empty street, a 4-digit ZIP, a negative height, or 200 × 200 × 200 cm.

## The two mechanisms

### Attributes API: one column, one object (`Money`)

[`app/models/money.rb`](app/models/money.rb) is a plain `Data` value object.
[`app/types/money_type.rb`](app/types/money_type.rb) subclasses
`ActiveRecord::Type::Value` and implements the three hooks:

- `cast_value` for assignment (form params, `Product.new(price: "12.50")`),
- `deserialize` for database → Ruby,
- `serialize` for Ruby → database, which also makes `Product.where(price: money)` work.

The model just declares `attribute :price, MoneyType.new`. The attribute name
has to match the column name; the Attributes API only swaps the type.

Things that bit while building it:

- **Unparseable input casts to `nil`.** `"abc"` becomes `nil`, and the original
  string is kept in `price_before_type_cast`. Form helpers re-render that raw
  value automatically. The validator has to look at it too, otherwise the user
  sees "can't be blank" for something they typed. `MoneyValidator` mirrors
  what Rails' `NumericalityValidator` does: it checks `price_came_from_user?`
  and reads `price_before_type_cast`.
- **`presence: true` overlaps with that.** Both would fire for `"abc"`, so
  `MoneyValidator` owns the blank check as well (`allow_blank: true` makes
  the price optional).
- **Column defaults arrive as strings.** A new record's default `0` comes out
  of the schema as `"0"`, and `deserialize` receives it. `Money#initialize`
  coerces with `Integer(...)`.

### `composed_of`: several columns, one object (`Address`, `Dimensions`)

`composed_of` reads the mapped columns into one object and writes an assigned
object back out to the columns:

```ruby
composed_of :address,
  mapping: { address_street: :street, address_city: :city, address_postal_code: :postal_code },
  allow_nil: true,
  constructor: ->(street, city, postal_code) { Address.new(street:, city:, postal_code:) },
  converter: ->(attributes) { Address.build(attributes) }
```

- `constructor:` receives the columns positionally in mapping order. The
  default `:new` would work for a `Data`/`Struct`; our value objects take
  keyword arguments, hence the lambda.
- `converter:` runs whenever something that isn't already an `Address` is
  assigned. That is how the nested hash posted by `fields_for :address`
  becomes an `Address`. `ValueObject.build` returns `nil` when every value is
  blank, which with `allow_nil: true` clears the columns.
- `composed_of` **freezes** every value object it hands out, so
  `product.address.street = "x"` raises `FrozenError`. Build a new one instead.

## Validating the composed value objects

The approach that ended up cleanest: **the value object validates itself**,
and the model copies the errors over. Both `Address` and `Dimensions` include
[`ValueObject`](app/models/concerns/value_object.rb), which mixes in
`ActiveModel::Model` and `ActiveModel::Attributes`. This works even though
`composed_of` freezes them: `ActiveModel::Validations#freeze` pre-initialises
the errors object precisely so frozen models can run `valid?`.

[`ComposedValidator`](app/validators/composed_validator.rb) does the copying
and offers two placements:

```ruby
validates :address,    presence: true, composed: true      # keys "address.street"
validates :dimensions, composed: { errors_on: :columns }   # keys "width_cm"
```

**Nested keys (`errors_on: :nested`, the default)** import each error as
`address.street`, the same shape `accepts_nested_attributes_for` produces via
`errors.import`. Pair it with `fields_for :address, product.address`: the nested
builder's object *is* the value object, which still carries its own errors, so
`field_with_errors` wrapping and inline messages come for free. Full messages
on the product ("Address street can't be blank") come from
`activerecord.attributes.product/address.street` in
[`config/locales/en.yml`](config/locales/en.yml); without that entry Rails would
humanize just the last segment and say "Street can't be blank".

**Column keys (`errors_on: :columns`)** re-key each error to the database
column using the `composed_of` reflection's `mapping`. Pair it with plain
fields bound to the columns (`form.text_field :width_cm`). Nothing about the
value object leaks into the form. This is a good fit when the columns are
also edited directly elsewhere.

In both placements an error the value object adds to `:base` (the cross-field
carrier-limit rule in `Dimensions`) lands on the composed attribute itself
(`:dimensions`), which the form renders once under the fieldset.

Alternatives that were considered:

- `validates_associated :address` works on value objects too (it only needs
  `valid?`), but it adds a single "Address is invalid" to the product. Fine if
  the form shows the value object's own errors inline and you don't need
  details in the summary.
- `validates :address_street, presence: true` and friends directly on the
  columns. Simplest when there is no cross-field rule and no reuse of the
  value object outside this model.

## A gotcha to know about

`composed_of` caches the value object per record. After `product.address` has
been read once, writing a column directly (`product.address_city = "Oakland"`)
does **not** refresh `product.address` until `reload`. Assigning through the
writer (`product.address = ...`) keeps both in sync, which is one more reason
to prefer the nested `fields_for` style when the form edits the whole value.
`test/models/product_test.rb` has a test that pins this behaviour down.

## Where to look

```
app/models/product.rb                  the declarations, with comments
app/models/money.rb                    Data value object (Attributes API)
app/types/money_type.rb                ActiveRecord::Type::Value subclass
app/validators/money_validator.rb      raw-input-aware validator
app/models/concerns/value_object.rb    ActiveModel-based value object base
app/models/address.rb                  composed_of value object, nested errors
app/models/dimensions.rb               composed_of value object, column errors, cross-field rule
app/validators/composed_validator.rb   copies value-object errors onto the record
app/views/products/_form.html.erb      the three form styles side by side
app/helpers/application_helper.rb      inline_errors(form, attribute)
config/locales/en.yml                  nested attribute names and custom messages
test/models/product_test.rb            behaviour of all three, incl. the cache gotcha
test/controllers/products_controller_test.rb   the rendered errors
```
