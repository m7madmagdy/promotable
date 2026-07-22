require "rails_helper"

RSpec.describe Promotable::Adjustment do
  before do
    @promo = create_promotion
    @action = Promotable::Actions::PercentageDiscount.create!(
      promotion: @promo,
      preferences: { percentage: 10 }
    )
    @order = create_order
  end

  it "validates amount presence" do
    adjustment = described_class.new(
      promotion: @promo,
      promotion_action: @action,
      adjustable: @order,
      amount: nil,
      label: "Test"
    )

    expect(adjustment).not_to be_valid
  end

  it "validates label presence" do
    adjustment = described_class.new(
      promotion: @promo,
      promotion_action: @action,
      adjustable: @order,
      amount: -10,
      label: nil
    )

    expect(adjustment).not_to be_valid
  end

  it "returns credit? true for negative amounts" do
    adjustment = described_class.create!(
      promotion: @promo,
      promotion_action: @action,
      adjustable: @order,
      amount: -10,
      label: "Discount"
    )

    expect(adjustment.credit?).to be(true)
    expect(adjustment.debit?).to be(false)
  end

  it "eligible scope returns only eligible adjustments" do
    described_class.create!(
      promotion: @promo,
      promotion_action: @action,
      adjustable: @order,
      amount: -10,
      label: "Eligible",
      eligible: true
    )
    described_class.create!(
      promotion: @promo,
      promotion_action: @action,
      adjustable: @order,
      amount: -5,
      label: "Ineligible",
      eligible: false
    )

    expect(described_class.eligible.count).to eq(1)
  end

  it "for_promotable scope filters by adjustable" do
    described_class.create!(
      promotion: @promo,
      promotion_action: @action,
      adjustable: @order,
      amount: -10,
      label: "Mine"
    )

    other_order = create_order
    described_class.create!(
      promotion: @promo,
      promotion_action: @action,
      adjustable: other_order,
      amount: -5,
      label: "Other"
    )

    expect(described_class.for_promotable(@order).count).to eq(1)
  end
end
