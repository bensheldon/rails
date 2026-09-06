class CreateProducts < ActiveRecord::Migration[8.2]
  def change
    create_table :products do |t|
      t.string :name, null: false

      # Attributes API: ONE column backs the Money value object (stored as cents).
      t.integer :price, null: false, default: 0

      # composed_of: THREE columns back the Address value object.
      t.string :address_street
      t.string :address_city
      t.string :address_postal_code

      # composed_of: THREE columns back the Dimensions value object.
      t.decimal :width_cm, precision: 8, scale: 2
      t.decimal :height_cm, precision: 8, scale: 2
      t.decimal :depth_cm, precision: 8, scale: 2

      t.timestamps
    end
  end
end
