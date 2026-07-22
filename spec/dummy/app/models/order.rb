class Order < ApplicationRecord
  acts_as_promotable

  belongs_to :client, optional: false
  belongs_to :user, optional: false

  before_validation :set_total_after_discounts, on: :create

  def promotable_amount
    BigDecimal(total_amount.to_s)
  end

  def promotable_items
    Array.new(item_count, :item)
  end

  def promotable_shipping_cost
    BigDecimal(shipping_cost.to_s)
  end

  private

  def set_total_after_discounts
    self.total_after_discounts = total_amount if total_after_discounts.nil?
  end
end
