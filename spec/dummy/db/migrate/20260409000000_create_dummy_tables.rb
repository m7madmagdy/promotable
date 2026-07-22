class CreateDummyTables < ActiveRecord::Migration[8.0]
  def change
    create_table :clients do |t|
      t.string :name, null: false

      t.timestamps
    end

    create_table :orders do |t|
      t.references :client, null: false, foreign_key: true
      t.decimal :total_amount, null: false, default: 0, precision: 15, scale: 4
      t.decimal :shipping_cost, null: false, default: 0, precision: 15, scale: 4
      t.integer :item_count, null: false, default: 0

      t.timestamps
    end

    create_table :users do |t|
      t.references :client, null: false, foreign_key: true
      t.string :name, null: false
      t.string :promotion_group

      t.timestamps
    end
  end
end
