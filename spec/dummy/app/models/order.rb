class Order < ApplicationRecord
  acts_as_promotable

  def promotable_amount
    BigDecimal(total_amount.to_s)
  end

  def promotable_items
    Array.new(item_count, :item)
  end

  def promotable_shipping_cost
    BigDecimal(shipping_cost.to_s)
  end
end
