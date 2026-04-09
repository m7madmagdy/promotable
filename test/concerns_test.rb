require "test_helper"

class Promotable::ConcernsTest < ActiveSupport::TestCase
  test "Order responds to acts_as_promotable methods" do
    order = Order.create!(total_amount: 100, shipping_cost: 10, item_count: 2)

    assert order.respond_to?(:apply_promotion_code)
    assert order.respond_to?(:apply_best_promotions)
    assert order.respond_to?(:remove_all_promotions)
    assert order.respond_to?(:recalculate_promotions)
    assert order.respond_to?(:promotion_total_discount)
    assert order.respond_to?(:promotable_adjustments)
  end

  test "User responds to acts_as_promoter methods" do
    user = User.create!(name: "Tester")

    assert user.respond_to?(:promotion_code_usages)
    assert user.respond_to?(:promotion_usage_count)
    assert user.respond_to?(:used_promotion?)
  end

  test "Order#apply_promotion_code redeems a code" do
    promo = Promotable::Promotion.create!(
      name: "Code Promo",
      active: true,
      starts_at: 1.day.ago,
      expires_at: 1.day.from_now
    )
    Promotable::PromotionCode.create!(promotion: promo, code: "ORDERCODE")
    Promotable::Actions::FixedAmountDiscount.create!(
      promotion: promo,
      preferences: { amount: 10 }
    )

    order = Order.create!(total_amount: 50, shipping_cost: 0, item_count: 1)
    user = User.create!(name: "Redeemer")

    order.apply_promotion_code("ORDERCODE", user: user)

    assert_equal 1, order.promotable_adjustments.count
    assert_equal BigDecimal("-10"), order.promotion_total_discount
  end

  test "Order#promotion_total_discount sums eligible adjustments" do
    promo = Promotable::Promotion.create!(
      name: "Multi Action",
      active: true,
      starts_at: 1.day.ago,
      expires_at: 1.day.from_now
    )
    action1 = Promotable::Actions::PercentageDiscount.create!(
      promotion: promo,
      preferences: { percentage: 10 }
    )
    action2 = Promotable::Actions::FixedAmountDiscount.create!(
      promotion: promo,
      preferences: { amount: 5 }
    )

    order = Order.create!(total_amount: 100, shipping_cost: 0, item_count: 1)

    Promotable::Adjustment.create!(
      promotion: promo,
      promotion_action: action1,
      adjustable: order,
      amount: -10,
      label: "10%"
    )
    Promotable::Adjustment.create!(
      promotion: promo,
      promotion_action: action2,
      adjustable: order,
      amount: -5,
      label: "Flat"
    )

    assert_equal BigDecimal("-15"), order.promotion_total_discount
  end

  test "User#promotion_usage_count returns correct count" do
    user = User.create!(name: "Counter")
    promo = Promotable::Promotion.create!(name: "Count Test", active: true)
    code = Promotable::PromotionCode.create!(promotion: promo, code: "COUNT1")
    order = Order.create!(total_amount: 50, shipping_cost: 0, item_count: 1)

    Promotable::CodeUsage.create!(
      promotion_code: code,
      user: user,
      promotable: order
    )

    assert_equal 1, user.promotion_usage_count(promo)
    assert user.used_promotion?(promo)
  end
end
