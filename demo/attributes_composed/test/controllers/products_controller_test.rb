require "test_helper"

class ProductsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @product = products(:desk)
  end

  test "index lists products with their value objects" do
    get products_url

    assert_response :success
    assert_select "td", text: "$649.00"
    assert_select "td", text: "1 Market St, San Francisco 94105"
    assert_select "td", text: "120 × 60 × 8 cm"
  end

  test "create with nested address params" do
    assert_difference("Product.count") do
      post products_url, params: { product: {
        name: "Monitor",
        price: "$299.99",
        address: { street: "500 W Madison St", city: "Chicago", postal_code: "60661" },
        width_cm: "61", height_cm: "36", depth_cm: "5"
      } }
    end

    product = Product.last
    assert_redirected_to product_url(product)
    assert_equal Money.new(cents: 29_999), product.price
    assert_equal "Chicago", product.address.city
    assert_equal Dimensions.new(width: 61, height: 36, depth: 5), product.dimensions
  end

  test "update with valid params" do
    patch product_url(@product), params: { product: { price: "700", address: { street: "1 Market St", city: "San Francisco", postal_code: "94105" } } }

    assert_redirected_to product_url(@product)
    assert_equal Money.new(cents: 70_000), @product.reload.price
  end

  test "update with invalid values re-renders the form with errors from every value object" do
    patch product_url(@product), params: { product: {
      name: "Standing desk",
      price: "abc",
      address: { street: "", city: "San Francisco", postal_code: "9410" },
      width_cm: "200", height_cm: "200", depth_cm: "200"
    } }

    assert_response :unprocessable_entity

    # Summary at the top, full messages built from the product's perspective.
    assert_select ".error-summary li", text: /Price is not a valid amount \(got abc\)/
    assert_select ".error-summary li", text: /Address street can't be blank/
    assert_select ".error-summary li", text: /Address postal code must be a ZIP code/
    assert_select ".error-summary li", text: /Dimensions are too large to ship/

    # Attributes API: the raw input is re-rendered and the field is flagged.
    assert_select ".field_with_errors input[name='product[price]'][value='abc']"

    # Nested fields_for: the Address value object's own errors flag its fields.
    assert_select ".field_with_errors input[name='product[address][street]']"
    assert_select ".field_with_errors input[name='product[address][postal_code]'][value='9410']"
    assert_select "input[name='product[address][city]']"
    assert_select ".field_with_errors input[name='product[address][city]']", count: 0

    # Column-bound fields: the cross-field error is shown once under the fieldset,
    # and no individual dimension field is flagged.
    assert_select "ul.inline-errors li", text: /too large to ship/
    assert_select ".field_with_errors input[name='product[width_cm]']", count: 0
  end

  test "update with an empty address fieldset reports the composed attribute as blank" do
    patch product_url(@product), params: { product: { address: { street: "", city: "", postal_code: "" } } }

    assert_response :unprocessable_entity
    assert_select ".error-summary li", text: /Address can't be blank/
  end

  test "destroy" do
    assert_difference("Product.count", -1) do
      delete product_url(@product)
    end

    assert_redirected_to products_url
  end
end
