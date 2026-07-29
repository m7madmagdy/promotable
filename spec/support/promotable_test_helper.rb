module PromotableTestHelper
  def create_client(attrs = {})
    Client.create!({ name: "Test Client" }.merge(attrs))
  end

  def create_promotion(attrs = {})
    Promotable::Promotion.create!({
      name: "Test Promotion",
      active: true,
      starts_at: 1.day.ago,
      expires_at: 1.day.from_now
    }.merge(attrs))
  end

  def create_order(attrs = {})
    attrs = attrs.dup
    attrs[:client] ||= create_client
    attrs[:user] ||= create_user(client: attrs[:client])

    Order.create!({
      total_amount: 100,
      shipping_cost: 10,
      item_count: 3
    }.merge(attrs))
  end

  def create_user(attrs = {})
    attrs = attrs.dup
    attrs[:client] ||= create_client

    User.create!({ name: "Test User" }.merge(attrs))
  end

  def create_line_item(order, attrs = {})
    order.line_items.create!({
      variant_sku: attrs.fetch(:variant_sku, "SKU-#{SecureRandom.hex(3)}"),
      quantity:    attrs.fetch(:quantity, 1),
      price:       attrs.fetch(:price, 10),
      price_after_discount: attrs.fetch(:price_after_discount, attrs.fetch(:price, 10))
    })
  end

  def create_promotion_with_code(code: "SAVE10", **promo_attrs)
    promo = create_promotion(**promo_attrs)
    promo.codes.create!(code: code)
    promo
  end
end
