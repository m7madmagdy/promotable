require "rails_helper"

RSpec.describe Promotable::Actions::CappedPercentageDiscount do
  let(:promo) { create_promotion }
  let(:order) { create_order(total_amount: 100) }

  it "computes the percentage when under the cap" do
    action = described_class.create!(promotion: promo, preferences: { percentage: 20, max_amount: 30 })
    expect(action.compute_amount(order)).to eq(BigDecimal("-20"))
  end

  it "clamps to max_amount when the percentage exceeds it" do
    order = create_order(total_amount: 500)
    action = described_class.create!(promotion: promo, preferences: { percentage: 20, max_amount: 30 })
    expect(action.compute_amount(order)).to eq(BigDecimal("-30"))
  end

  it "is uncapped when max_amount is blank" do
    order = create_order(total_amount: 500)
    action = described_class.create!(promotion: promo, preferences: { percentage: 20 })
    expect(action.compute_amount(order)).to eq(BigDecimal("-100"))
  end

  it "labels the adjustment with the percentage and cap" do
    action = described_class.create!(promotion: promo, preferences: { percentage: 20, max_amount: 30 })
    action.apply(order)
    expect(Promotable::Adjustment.last.label).to match(/20% off.*max 30/)
  end
end
