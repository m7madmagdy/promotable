class Order < ApplicationRecord
  acts_as_promotable

  # `total_amount` is the pre-hive column name kept for spec compatibility;
  # the underlying column is now `items_total` to mirror hive-backend.
  alias_attribute :total_amount, :items_total

  belongs_to :client, optional: false
  belongs_to :user, optional: false

  has_many :line_items, as: :orderable, dependent: :destroy

  before_validation :set_total_after_discounts, on: :create

  def promotable_amount
    BigDecimal(items_total.to_s)
  end

  def promotable_items
    line_items.to_a
  end

  def promotable_item_count
    line_items.sum(:quantity)
  end

  def promotable_shipping_cost
    BigDecimal(shipping_cost.to_s)
  end

  private

  def set_total_after_discounts
    self.total_after_discounts = items_total if total_after_discounts.nil? || total_after_discounts.zero?
  end
end
