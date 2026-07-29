class AlignDummyModelsWithHive < ActiveRecord::Migration[8.1]
  # Aligns the dummy Rails app's schema with hive-backend's shape so the
  # gem can be exercised against representative host models: Client, User,
  # Order, LineItem.
  #
  # This is a greenfield migration — no data backfill is required. The
  # `total_amount` column is renamed to `items_total` to match hive; the
  # Order model exposes `total_amount` as an alias_attribute for backward
  # compatibility with existing specs.
  def change
    change_table :clients, bulk: true do |t|
      t.integer :client_type,    null: false, default: 0
      t.string  :currency,       null: false, default: "USD"
      t.string  :source
      t.string  :support_number
      t.string  :prefix_code,    limit: 3, null: false, default: "HIV"
    end

    change_table :users, bulk: true do |t|
      t.string :email
      t.string :mobile_number
      t.date   :date_of_birth
      t.boolean :verified, null: false, default: false
    end
    add_index :users, [ :mobile_number, :client_id ], unique: true, where: "mobile_number IS NOT NULL"

    rename_column :orders, :total_amount, :items_total

    change_table :orders, bulk: true do |t|
      t.string  :number
      t.string  :status
      t.string  :source
      t.decimal :delivery_fee, precision: 15, scale: 4, null: false, default: 0
      t.decimal :total,        precision: 15, scale: 4, null: false, default: 0
    end
    add_index :orders, :number, unique: true, where: "number IS NOT NULL"

    create_table :line_items do |t|
      t.references :orderable, polymorphic: true, null: false
      t.string     :variant_sku, null: false
      t.integer    :quantity,   null: false, default: 1
      t.decimal    :price,                precision: 15, scale: 4, null: false, default: 0
      t.decimal    :price_after_discount, precision: 15, scale: 4, null: false, default: 0

      t.timestamps
    end
    add_index :line_items, :variant_sku
  end
end
