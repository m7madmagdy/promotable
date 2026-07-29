require "rails_helper"

RSpec.describe Promotable::Rules::MaximumAmountRule do
  let(:promo) { create_promotion }
  let(:order) { create_order(total_amount: 100) }
  let(:rule)  { described_class.new(promotion: promo, preferences: { maximum_amount: max }) }

  context "when amount is below the ceiling" do
    let(:max) { 200 }

    it "is eligible" do
      expect(rule.eligible?(order)).to be(true)
    end
  end

  context "when amount equals the ceiling" do
    let(:max) { 100 }

    it "is eligible" do
      expect(rule.eligible?(order)).to be(true)
    end
  end

  context "when amount exceeds the ceiling" do
    let(:max) { 50 }

    it "is ineligible" do
      expect(rule.eligible?(order)).to be(false)
    end
  end
end
