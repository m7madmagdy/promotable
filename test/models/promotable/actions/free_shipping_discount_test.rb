require "test_helper"

class Promotable::Actions::FreeShippingDiscountTest < ActiveSupport::TestCase
  setup do
    @promo = create_promotion
    @action = Promotable::Actions::FreeShippingDiscount.create!(promotion: @promo)
    @order = create_order(shipping_cost: 15)
  end

  test "compute_amount returns negative shipping cost" do
    amount = @action.compute_amount(@order)
    assert_equal BigDecimal("-15"), amount
  end

  test "compute_amount returns zero when no shipping cost method" do
    plain = Object.new
    def plain.promotable_amount; BigDecimal("100"); end

    amount = @action.compute_amount(plain)
    assert_equal BigDecimal("0"), amount
  end

  test "apply creates an adjustment for shipping" do
    assert_difference "Promotable::Adjustment.count", 1 do
      @action.apply(@order)
    end

    adj = Promotable::Adjustment.last
    assert_equal BigDecimal("-15"), adj.amount
    assert_equal "Free shipping", adj.label
  end

  test "apply does nothing when shipping cost is zero" do
    order = create_order(shipping_cost: 0)
    assert_no_difference "Promotable::Adjustment.count" do
      @action.apply(order)
    end
  end
end
