class ProductsController < ApplicationController
  before_action :set_product, only: %i[ show edit update destroy ]

  def index
    @products = Product.order(:name)
  end

  def show
  end

  def new
    @product = Product.new
  end

  def edit
  end

  def create
    @product = Product.new(product_params)

    if @product.save
      redirect_to @product, notice: "Product was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @product.update(product_params)
      redirect_to @product, notice: "Product was successfully updated.", status: :see_other
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @product.destroy!
    redirect_to products_path, notice: "Product was successfully destroyed.", status: :see_other
  end

  private
    def set_product
      @product = Product.find(params.expect(:id))
    end

    # +price+ arrives as a string and is cast by MoneyType.
    # +address+ arrives as a nested hash from +fields_for+ and is turned into an
    # Address by the composed_of converter.
    # The dimension columns arrive individually and are cast as decimals.
    def product_params
      params.expect(product: [ :name, :price, :width_cm, :height_cm, :depth_cm, address: [ :street, :city, :postal_code ] ])
    end
end
