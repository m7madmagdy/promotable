require "test_helper"

class Promotable::Actions::PercentageDiscountTest < ActiveSupport::TestCase
  setup do
    @promo = create_promotion
    @action = Promotable::Actions::PercentageDiscount.create!(
      promotion: @promo,
      preferences: { percentage: 10 }
    )
    @order = create_order(total_amount: 200)
  end

  test "compute_amount returns negative percentage of promotable_amount" do
    amount = @action.compute_amount(@order)
    assert_equal BigDecimal("-20"), amount
  end

  test "apply creates an adjustment" do
    assert_difference "Promotable::Adjustment.count", 1 do
      @action.apply(@order)
    end

    adj = Promotable::Adjustment.last
    assert_equal BigDecimal("-20"), adj.amount
    assert_equal "10% discount", adj.label
    assert adj.eligible?
  end

  test "apply does nothing when amount is zero" do
    order = create_order(total_amount: 0)
    assert_no_difference "Promotable::Adjustment.count" do
      @action.apply(order)
    end
  end

  test "undo removes adjustments for the promotable" do
    @action.apply(@order)
    assert_equal 1, Promotable::Adjustment.count

    @action.undo(@order)
    assert_equal 0, Promotable::Adjustment.count
  end
end
