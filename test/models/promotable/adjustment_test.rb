require "test_helper"

class Promotable::AdjustmentTest < ActiveSupport::TestCase
  setup do
    @promo = create_promotion
    @action = Promotable::Actions::PercentageDiscount.create!(
      promotion: @promo,
      preferences: { percentage: 10 }
    )
    @order = create_order
  end

  test "validates amount presence" do
    adj = Promotable::Adjustment.new(
      promotion: @promo,
      promotion_action: @action,
      adjustable: @order,
      amount: nil,
      label: "Test"
    )
    assert_not adj.valid?
  end

  test "validates label presence" do
    adj = Promotable::Adjustment.new(
      promotion: @promo,
      promotion_action: @action,
      adjustable: @order,
      amount: -10,
      label: nil
    )
    assert_not adj.valid?
  end

  test "credit? returns true for negative amounts" do
    adj = Promotable::Adjustment.create!(
      promotion: @promo,
      promotion_action: @action,
      adjustable: @order,
      amount: -10,
      label: "Discount"
    )
    assert adj.credit?
    assert_not adj.debit?
  end

  test "scope eligible returns only eligible adjustments" do
    Promotable::Adjustment.create!(
      promotion: @promo,
      promotion_action: @action,
      adjustable: @order,
      amount: -10,
      label: "Eligible",
      eligible: true
    )
    Promotable::Adjustment.create!(
      promotion: @promo,
      promotion_action: @action,
      adjustable: @order,
      amount: -5,
      label: "Ineligible",
      eligible: false
    )

    assert_equal 1, Promotable::Adjustment.eligible.count
  end

  test "scope for_promotable filters by adjustable" do
    Promotable::Adjustment.create!(
      promotion: @promo,
      promotion_action: @action,
      adjustable: @order,
      amount: -10,
      label: "Mine"
    )

    other_order = create_order
    Promotable::Adjustment.create!(
      promotion: @promo,
      promotion_action: @action,
      adjustable: other_order,
      amount: -5,
      label: "Other"
    )

    assert_equal 1, Promotable::Adjustment.for_promotable(@order).count
  end
end
