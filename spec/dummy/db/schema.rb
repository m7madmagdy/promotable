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

ActiveRecord::Schema[8.1].define(version: 2026_07_26_000004) do
  create_table "clients", force: :cascade do |t|
    t.integer "client_type", default: 0, null: false
    t.datetime "created_at", null: false
    t.string "currency", default: "USD", null: false
    t.string "name", null: false
    t.string "prefix_code", limit: 3, default: "HIV", null: false
    t.string "source"
    t.string "support_number"
    t.datetime "updated_at", null: false
  end

  create_table "line_items", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "orderable_id", null: false
    t.string "orderable_type", null: false
    t.decimal "price", precision: 15, scale: 4, default: "0.0", null: false
    t.decimal "price_after_discount", precision: 15, scale: 4, default: "0.0", null: false
    t.integer "quantity", default: 1, null: false
    t.datetime "updated_at", null: false
    t.string "variant_sku", null: false
    t.index ["orderable_type", "orderable_id"], name: "index_line_items_on_orderable"
    t.index ["variant_sku"], name: "index_line_items_on_variant_sku"
  end

  create_table "orders", force: :cascade do |t|
    t.integer "client_id"
    t.datetime "created_at", null: false
    t.decimal "delivery_fee", precision: 15, scale: 4, default: "0.0", null: false
    t.integer "item_count", default: 0, null: false
    t.decimal "items_total", precision: 15, scale: 4, default: "0.0", null: false
    t.string "number"
    t.decimal "shipping_cost", precision: 15, scale: 4, default: "0.0", null: false
    t.string "source"
    t.string "status"
    t.decimal "total", precision: 15, scale: 4, default: "0.0", null: false
    t.decimal "total_after_discounts", precision: 15, scale: 4, default: "0.0", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.index ["client_id"], name: "index_orders_on_client_id"
    t.index ["number"], name: "index_orders_on_number", unique: true, where: "number IS NOT NULL"
    t.index ["user_id"], name: "index_orders_on_user_id"
  end

  create_table "promotable_actions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.json "preferences", default: {}
    t.integer "promotion_id", null: false
    t.string "type", null: false
    t.datetime "updated_at", null: false
    t.index ["promotion_id"], name: "index_promotable_actions_on_promotion_id"
    t.index ["type"], name: "index_promotable_actions_on_type"
  end

  create_table "promotable_adjustments", force: :cascade do |t|
    t.integer "adjustable_id", null: false
    t.string "adjustable_type", null: false
    t.decimal "amount", precision: 15, scale: 4, null: false
    t.bigint "client_id"
    t.datetime "created_at", null: false
    t.boolean "eligible", default: true, null: false
    t.string "label"
    t.json "metadata", default: {}
    t.integer "promotion_action_id", null: false
    t.integer "promotion_id", null: false
    t.datetime "updated_at", null: false
    t.index ["adjustable_type", "adjustable_id"], name: "index_promotable_adjustments_on_adjustable"
    t.index ["client_id"], name: "index_promotable_adjustments_on_client_id"
    t.index ["eligible"], name: "index_promotable_adjustments_on_eligible"
    t.index ["promotion_action_id"], name: "index_promotable_adjustments_on_promotion_action_id"
    t.index ["promotion_id"], name: "index_promotable_adjustments_on_promotion_id"
  end

  create_table "promotable_code_usages", force: :cascade do |t|
    t.bigint "client_id"
    t.datetime "created_at", null: false
    t.integer "promotable_id", null: false
    t.string "promotable_type", null: false
    t.integer "promotion_code_id", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.string "user_type", null: false
    t.index ["client_id"], name: "index_promotable_code_usages_on_client_id"
    t.index ["promotable_type", "promotable_id"], name: "index_promotable_code_usages_on_promotable"
    t.index ["promotion_code_id"], name: "index_promotable_code_usages_on_promotion_code_id"
    t.index ["user_type", "user_id"], name: "index_promotable_code_usages_on_user"
  end

  create_table "promotable_promotion_codes", force: :cascade do |t|
    t.bigint "client_id"
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.integer "promotion_id", null: false
    t.datetime "updated_at", null: false
    t.integer "usage_count", default: 0, null: false
    t.integer "usage_limit"
    t.index ["client_id", "code"], name: "index_promotable_promotion_codes_on_client_id_and_code", unique: true
    t.index ["client_id"], name: "index_promotable_promotion_codes_on_client_id"
    t.index ["promotion_id"], name: "index_promotable_promotion_codes_on_promotion_id"
  end

  create_table "promotable_promotions", force: :cascade do |t|
    t.boolean "active", default: false, null: false
    t.integer "client_id"
    t.datetime "created_at", null: false
    t.text "description"
    t.datetime "expires_at"
    t.json "metadata", default: {}
    t.string "name", null: false
    t.integer "per_user_limit"
    t.integer "priority", default: 0, null: false
    t.string "promotion_type"
    t.boolean "stackable", default: true, null: false
    t.datetime "starts_at"
    t.datetime "updated_at", null: false
    t.integer "usage_count", default: 0, null: false
    t.integer "usage_limit"
    t.index ["active"], name: "index_promotable_promotions_on_active"
    t.index ["client_id"], name: "index_promotable_promotions_on_client_id"
    t.index ["priority"], name: "index_promotable_promotions_on_priority"
    t.index ["starts_at", "expires_at"], name: "index_promotable_promotions_on_starts_at_and_expires_at"
  end

  create_table "promotable_rules", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.json "preferences", default: {}
    t.integer "promotion_id", null: false
    t.string "type", null: false
    t.datetime "updated_at", null: false
    t.index ["promotion_id"], name: "index_promotable_rules_on_promotion_id"
    t.index ["type"], name: "index_promotable_rules_on_type"
  end

  create_table "users", force: :cascade do |t|
    t.integer "client_id"
    t.datetime "created_at", null: false
    t.date "date_of_birth"
    t.string "email"
    t.string "mobile_number"
    t.string "name", null: false
    t.string "promotion_group"
    t.datetime "updated_at", null: false
    t.boolean "verified", default: false, null: false
    t.index ["client_id"], name: "index_users_on_client_id"
    t.index ["mobile_number", "client_id"], name: "index_users_on_mobile_number_and_client_id", unique: true, where: "mobile_number IS NOT NULL"
  end

  add_foreign_key "orders", "clients"
  add_foreign_key "orders", "users"
  add_foreign_key "promotable_actions", "promotable_promotions", column: "promotion_id"
  add_foreign_key "promotable_adjustments", "clients"
  add_foreign_key "promotable_adjustments", "promotable_actions", column: "promotion_action_id"
  add_foreign_key "promotable_adjustments", "promotable_promotions", column: "promotion_id"
  add_foreign_key "promotable_code_usages", "clients"
  add_foreign_key "promotable_code_usages", "promotable_promotion_codes", column: "promotion_code_id"
  add_foreign_key "promotable_promotion_codes", "clients"
  add_foreign_key "promotable_promotion_codes", "promotable_promotions", column: "promotion_id"
  add_foreign_key "promotable_promotions", "clients"
  add_foreign_key "promotable_rules", "promotable_promotions", column: "promotion_id"
  add_foreign_key "users", "clients"
end
