class AddTotalAfterDiscountsToOrders < ActiveRecord::Migration[8.0]
  def change
    unless column_exists?(:orders, :total_after_discounts)
      add_column :orders, :total_after_discounts, :decimal,
                 precision: 15,
                 scale: 4,
                 null: false,
                 default: 0
    end

    reversible do |dir|
      dir.up do
        execute <<~SQL
          UPDATE orders
          SET total_after_discounts = total_amount
          WHERE total_after_discounts = 0
        SQL
      end
    end
  end
end
