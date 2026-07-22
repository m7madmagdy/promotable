class AddClientToPromotablePromotions < ActiveRecord::Migration[8.1]
  def change
    return if column_exists?(:promotable_promotions, :client_id) && column_exists?(:promotable_promotions, :client_type)

    add_reference :promotable_promotions, :client, polymorphic: true, index: true
  end
end
