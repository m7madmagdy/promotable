class LineItem < ApplicationRecord
  belongs_to :orderable, polymorphic: true

  # Convenience association: in the dummy the only orderable is Order.
  belongs_to :order,
             optional: true,
             foreign_key: :orderable_id,
             class_name: "Order",
             inverse_of: :line_items

  validates :variant_sku, :quantity, presence: true
  validates :quantity, numericality: { greater_than: 0 }

  after_save :sync_order
  after_destroy :sync_order

  private

  def sync_order
    return unless order.present?
    shipping_cost = order.shipping_cost || 0
    delivery_fee = order.delivery_fee || 0

    order.item_count = order.line_items.sum(:quantity)
    order.items_total = order.line_items.sum("quantity * price")
    order.total = order.items_total + delivery_fee + shipping_cost
    order.total_after_discounts = order.line_items.sum("quantity * price_after_discount") + delivery_fee + shipping_cost

    order.save!
  end
end
