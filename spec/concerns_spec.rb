require "rails_helper"

RSpec.describe "Promotable concerns" do
  it "adds promotable methods to Order" do
    order = create_order(total_amount: 100, shipping_cost: 10, item_count: 2)

    expect(order).to respond_to(:apply_promotion_code)
    expect(order).to respond_to(:apply_best_promotions)
    expect(order).to respond_to(:remove_all_promotions)
    expect(order).to respond_to(:recalculate_promotions)
    expect(order).to respond_to(:promotion_total_discount)
    expect(order).to respond_to(:promotable_adjustments)
  end

  it "adds promoter methods to User" do
    user = create_user(name: "Tester")

    expect(user).to respond_to(:promotion_code_usages)
    expect(user).to respond_to(:promotion_usage_count)
    expect(user).to respond_to(:used_promotion?)
  end

  it "redeems a code through Order#apply_promotion_code" do
    client = create_client(name: "Acme")
    Promotable.configuration.current_tenant_resolver = -> { client }

    promo = Promotable::Promotion.create!(
      name: "Code Promo",
      client: client,
      active: true,
      starts_at: 1.day.ago,
      expires_at: 1.day.from_now
    )
    Promotable::PromotionCode.create!(promotion: promo, code: "ORDERCODE")
    Promotable::Actions::PercentageDiscount.create!(
      promotion: promo,
      preferences: { percentage: 20 }
    )

    order = create_order(total_amount: 50, shipping_cost: 0, item_count: 1, client: client)
    user = create_user(name: "Redeemer", client: client)

    order.apply_promotion_code("ORDERCODE", user: user)

    expect(order.promotable_adjustments.count).to eq(1)
    expect(order.promotion_total_discount).to eq(BigDecimal("-10"))
    expect(order.reload.total_after_discounts.to_d).to eq(BigDecimal("40.0"))
  end

  it "sums eligible adjustments in Order#promotion_total_discount" do
    client = create_client(name: "Acme")
    Promotable.configuration.current_tenant_resolver = -> { client }

    promo = Promotable::Promotion.create!(
      name: "Multi Action",
      client: client,
      active: true,
      starts_at: 1.day.ago,
      expires_at: 1.day.from_now
    )
    action1 = Promotable::Actions::PercentageDiscount.create!(
      promotion: promo,
      preferences: { percentage: 10 }
    )
    action2 = Promotable::Actions::PercentageDiscount.create!(
      promotion: promo,
      preferences: { percentage: 5 }
    )

    order = create_order(total_amount: 100, shipping_cost: 0, item_count: 1, client: client)

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
      label: "5%"
    )

    expect(order.promotion_total_discount).to eq(BigDecimal("-15"))
  end

  it "returns usage counts through User#promotion_usage_count" do
    client = create_client(name: "Acme")
    Promotable.configuration.current_tenant_resolver = -> { client }

    user = create_user(name: "Counter", client: client)
    promo = Promotable::Promotion.create!(name: "Count Test", active: true, client: client)
    code = Promotable::PromotionCode.create!(promotion: promo, code: "COUNT1")
    order = create_order(total_amount: 50, shipping_cost: 0, item_count: 1, client: client)

    Promotable::CodeUsage.create!(
      promotion_code: code,
      user: user,
      promotable: order
    )

    expect(user.promotion_usage_count(promo)).to eq(1)
    expect(user.used_promotion?(promo)).to be(true)
  end

  it "returns available promotions scoped to the user client" do
    acme = create_client(name: "Acme")
    globex = create_client(name: "Globex")
    Promotable.configuration.current_tenant_resolver = -> { acme }

    user = create_user(client: acme)

    global_promo = create_promotion(name: "Global")
    acme_promo = create_promotion(name: "Acme", client: acme)
    create_promotion(name: "Globex", client: globex)

    expect(user.available_promotions).to include(global_promo, acme_promo)
    expect(user.available_promotions.map(&:name)).not_to include("Globex")
  end
end
