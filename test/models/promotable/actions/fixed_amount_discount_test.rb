require "test_helper"

class Promotable::Actions::FixedAmountDiscountTest < ActiveSupport::TestCase
  setup do
    @promo = create_promotion
    @action = Promotable::Actions::FixedAmountDiscount.create!(
      promotion: @promo,
      preferences: { amount: 15 }
    )
    @order = create_order(total_amount: 100)
  end

  test "compute_amount returns negative fixed amount" do
    amount = @action.compute_amount(@order)
    assert_equal BigDecimal("-15"), amount
  end

  test "compute_amount caps discount at promotable_amount" do
    small_order = create_order(total_amount: 10)
    amount = @action.compute_amount(small_order)
    assert_equal BigDecimal("-10"), amount
  end

  test "apply creates an adjustment" do
    assert_difference "Promotable::Adjustment.count", 1 do
      @action.apply(@order)
    end

    adj = Promotable::Adjustment.last
    assert_equal BigDecimal("-15"), adj.amount
  end

  test "apply does nothing when amount would be zero" do
    order = create_order(total_amount: 0)
    assert_no_difference "Promotable::Adjustment.count" do
      @action.apply(order)
    end
  end
end
