# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.2].define(version: 2026_09_06_210027) do
  create_table "products", force: :cascade do |t|
    t.string "name", null: false
    t.integer "price", default: 0, null: false
    t.string "address_street"
    t.string "address_city"
    t.string "address_postal_code"
    t.decimal "width_cm", precision: 8, scale: 2
    t.decimal "height_cm", precision: 8, scale: 2
    t.decimal "depth_cm", precision: 8, scale: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end
end
