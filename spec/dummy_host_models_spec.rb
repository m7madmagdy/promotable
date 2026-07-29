require "rails_helper"

# Integration coverage that exercises the promotable gem against the
# hive-aligned dummy host models (Client / User / Order / LineItem).
#
# Focused scenarios per user request:
#   1. PercentageDiscount (uncapped)
#   2. CappedPercentageDiscount (with and without a binding cap)
#   3. MinimumAmountRule gating a promotion
RSpec.describe "Hive-aligned host models", type: :model do
  let(:client) { create_client(name: "Acme", client_type: "b2c", currency: "USD") }
  let(:user)   { create_user(client: client, name: "Jane", email: "jane@example.com") }

  def build_order(items_total: 200, line_items: [])
    order = create_order(client: client, user: user, total_amount: items_total)
    line_items.each { |attrs| create_line_item(order, attrs) }
    order
  end

  describe "PercentageDiscount (uncapped)" do
    it "applies X% off the order's items_total via Applicator" do
      promo = create_promotion(client: client)
      promo.actions.create!(
        type: "Promotable::Actions::PercentageDiscount",
        preferences: { percentage: 15 }
      )

      order = build_order(items_total: 200)

      ActsAsTenant.with_tenant(client) do
        Promotable::Applicator.new(order, user: user).apply([ promo ])
      end

      adjustment = order.promotable_adjustments.last
      expect(adjustment.amount).to eq(BigDecimal("-30"))
      expect(order.reload.total_after_discounts).to eq(BigDecimal("170"))
    end
  end

  describe "CappedPercentageDiscount" do
    let!(:promo) do
      create_promotion(client: client).tap do |p|
        p.actions.create!(
          type: "Promotable::Actions::CappedPercentageDiscount",
          preferences: { percentage: 20, max_amount: 25 }
        )
      end
    end

    it "applies the raw percentage when it stays under the cap" do
      order = build_order(items_total: 100)

      ActsAsTenant.with_tenant(client) do
        Promotable::Applicator.new(order, user: user).apply([ promo ])
      end

      expect(order.promotable_adjustments.last.amount).to eq(BigDecimal("-20"))
    end

    it "clamps to max_amount when the percentage would exceed it" do
      order = build_order(items_total: 500)

      ActsAsTenant.with_tenant(client) do
        Promotable::Applicator.new(order, user: user).apply([ promo ])
      end

      adjustment = order.promotable_adjustments.last
      expect(adjustment.amount).to eq(BigDecimal("-25"))
      expect(adjustment.label).to match(/20% off.*max 25/)
    end
  end

  describe "MinimumAmountRule" do
    let!(:promo) do
      create_promotion(client: client).tap do |p|
        p.rules.create!(
          type: "Promotable::Rules::MinimumAmountRule",
          preferences: { minimum_amount: 100 }
        )
        p.actions.create!(
          type: "Promotable::Actions::PercentageDiscount",
          preferences: { percentage: 10 }
        )
      end
    end

    it "blocks the promotion when items_total is below the threshold" do
      small_order = build_order(items_total: 50)

      eligible = ActsAsTenant.with_tenant(client) do
        Promotable::Evaluator.new(small_order, user: user).eligible_promotions
      end

      expect(eligible).to be_empty
    end

    it "allows the promotion when items_total meets the threshold" do
      big_order = build_order(items_total: 150)

      eligible = ActsAsTenant.with_tenant(client) do
        Promotable::Evaluator.new(big_order, user: user).eligible_promotions
      end

      expect(eligible).to include(promo)
    end
  end

  describe "LineItem association" do
    it "exposes line items via #promotable_items and #promotable_item_count" do
      order = build_order(
        items_total: 60,
        line_items: [
          { variant_sku: "SKU-A", quantity: 2, price: 20 },
          { variant_sku: "SKU-B", quantity: 1, price: 20 }
        ]
      )

      expect(order.promotable_items.map(&:variant_sku)).to match_array([ "SKU-A", "SKU-B" ])
      expect(order.promotable_item_count).to eq(3)
    end
  end
end
