class CreatePromotableTables < ActiveRecord::Migration[8.1]
  def change
    return if table_exists?(:promotable_promotions)

    create_table :promotable_promotions do |t|
      t.string   :name,           null: false
      t.text     :description
      t.string   :promotion_type
      t.datetime :starts_at
      t.datetime :expires_at
      t.integer  :usage_limit
      t.integer  :per_user_limit
      t.integer  :usage_count,    null: false, default: 0
      t.boolean  :active,         null: false, default: false
      t.integer  :priority,       null: false, default: 0
      t.boolean  :stackable,      null: false, default: true
      t.json     :metadata,       default: {}

      t.timestamps
    end

    add_index :promotable_promotions, :active
    add_index :promotable_promotions, :priority
    add_index :promotable_promotions, [ :starts_at, :expires_at ]

    create_table :promotable_rules do |t|
      t.references :promotion, null: false, foreign_key: { to_table: :promotable_promotions }
      t.string     :type,      null: false
      t.json       :preferences, default: {}

      t.timestamps
    end

    add_index :promotable_rules, :type

    create_table :promotable_actions do |t|
      t.references :promotion, null: false, foreign_key: { to_table: :promotable_promotions }
      t.string     :type,      null: false
      t.json       :preferences, default: {}

      t.timestamps
    end

    add_index :promotable_actions, :type

    create_table :promotable_promotion_codes do |t|
      t.references :promotion, null: false, foreign_key: { to_table: :promotable_promotions }
      t.string     :code,        null: false
      t.integer    :usage_limit
      t.integer    :usage_count, null: false, default: 0

      t.timestamps
    end

    add_index :promotable_promotion_codes, :code, unique: true

    create_table :promotable_code_usages do |t|
      t.references :promotion_code, null: false, foreign_key: { to_table: :promotable_promotion_codes }
      t.references :user,           null: false, polymorphic: true
      t.references :promotable,     null: false, polymorphic: true

      t.timestamps
    end

    create_table :promotable_adjustments do |t|
      t.references :promotion,        null: false, foreign_key: { to_table: :promotable_promotions }
      t.references :promotion_action, null: false, foreign_key: { to_table: :promotable_actions }
      t.references :adjustable,       null: false, polymorphic: true
      t.decimal    :amount,    null: false, precision: 15, scale: 4
      t.string     :label
      t.boolean    :eligible,  null: false, default: true
      t.json       :metadata,  default: {}

      t.timestamps
    end

    add_index :promotable_adjustments, :eligible
  end
end
