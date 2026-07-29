require "rails_helper"

RSpec.describe Promotable::Actions::TieredDiscountAction do
  let(:promo) { create_promotion }
  let(:tiers) do
    [
      { min_amount: 50,  discount: 5,  type: "fixed" },
      { min_amount: 100, discount: 15, type: "fixed" },
      { min_amount: 200, discount: 20, type: "percentage" }
    ]
  end
  let(:action) { described_class.create!(promotion: promo, preferences: { tiers: tiers }) }

  it "picks the highest matching tier" do
    expect(action.compute_amount(create_order(total_amount: 60))).to  eq(BigDecimal("-5"))
    expect(action.compute_amount(create_order(total_amount: 150))).to eq(BigDecimal("-15"))
    expect(action.compute_amount(create_order(total_amount: 250))).to eq(BigDecimal("-50"))
  end

  it "returns zero when no tier matches" do
    expect(action.compute_amount(create_order(total_amount: 10))).to eq(BigDecimal("0"))
  end

  it "labels adjustments with the matching tier" do
    action.apply(create_order(total_amount: 150))
    expect(Promotable::Adjustment.last.label).to match(/15.*tier.*100/)
  end
end
