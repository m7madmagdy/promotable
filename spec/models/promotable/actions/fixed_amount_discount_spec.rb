require "rails_helper"

RSpec.describe Promotable::Actions::FixedAmountDiscount do
  let(:promo)  { create_promotion }
  let(:order)  { create_order(total_amount: 100) }
  let(:action) { described_class.create!(promotion: promo, preferences: { amount: 15 }) }

  describe "#compute_amount" do
    it "returns the negative fixed amount when below promotable_amount" do
      expect(action.compute_amount(order)).to eq(BigDecimal("-15"))
    end

    it "caps at the promotable_amount to prevent negative totals" do
      small_order = create_order(total_amount: 5)
      expect(action.compute_amount(small_order)).to eq(BigDecimal("-5"))
    end
  end

  describe "#apply" do
    it "creates an adjustment with a $X off label" do
      expect { action.apply(order) }.to change(Promotable::Adjustment, :count).by(1)
      adjustment = Promotable::Adjustment.last
      expect(adjustment.amount).to eq(BigDecimal("-15"))
      expect(adjustment.label).to match(/off/i)
    end

    it "does nothing when the promotable amount is zero" do
      zero_order = create_order(total_amount: 0)
      expect { action.apply(zero_order) }.not_to change(Promotable::Adjustment, :count)
    end
  end
end
