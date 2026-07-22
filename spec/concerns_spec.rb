require "rails_helper"

RSpec.describe "Promotable concerns" do
  it "adds promotable methods to Order" do
    order = Order.create!(total_amount: 100, shipping_cost: 10, item_count: 2)

    expect(order).to respond_to(:apply_promotion_code)
    expect(order).to respond_to(:apply_best_promotions)
    expect(order).to respond_to(:remove_all_promotions)
    expect(order).to respond_to(:recalculate_promotions)
    expect(order).to respond_to(:promotion_total_discount)
    expect(order).to respond_to(:promotable_adjustments)
  end

  it "adds promoter methods to User" do
    user = User.create!(name: "Tester")

    expect(user).to respond_to(:promotion_code_usages)
    expect(user).to respond_to(:promotion_usage_count)
    expect(user).to respond_to(:used_promotion?)
  end

  it "redeems a code through Order#apply_promotion_code" do
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

    expect(order.promotable_adjustments.count).to eq(1)
    expect(order.promotion_total_discount).to eq(BigDecimal("-10"))
  end

  it "sums eligible adjustments in Order#promotion_total_discount" do
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

    expect(order.promotion_total_discount).to eq(BigDecimal("-15"))
  end

  it "returns usage counts through User#promotion_usage_count" do
    user = User.create!(name: "Counter")
    promo = Promotable::Promotion.create!(name: "Count Test", active: true)
    code = Promotable::PromotionCode.create!(promotion: promo, code: "COUNT1")
    order = Order.create!(total_amount: 50, shipping_cost: 0, item_count: 1)

    Promotable::CodeUsage.create!(
      promotion_code: code,
      user: user,
      promotable: order
    )

    expect(user.promotion_usage_count(promo)).to eq(1)
    expect(user.used_promotion?(promo)).to be(true)
  end
end
