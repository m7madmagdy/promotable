require "rails_helper"

RSpec.describe Promotable::Rules::MinimumAmountRule do
  before do
    @promo = create_promotion
    @rule = described_class.create!(
      promotion: @promo,
      preferences: { minimum_amount: 50 }
    )
  end

  it "is eligible when order amount meets minimum" do
    order = create_order(total_amount: 100)

    expect(@rule.eligible?(order)).to be(true)
  end

  it "is eligible when order amount equals minimum" do
    order = create_order(total_amount: 50)

    expect(@rule.eligible?(order)).to be(true)
  end

  it "is ineligible when order amount is below minimum" do
    order = create_order(total_amount: 30)

    expect(@rule.eligible?(order)).to be(false)
  end

  it "preference_fields returns minimum_amount field" do
    fields = described_class.preference_fields

    expect(fields.size).to eq(1)
    expect(fields.first[:name]).to eq(:minimum_amount)
  end
end
