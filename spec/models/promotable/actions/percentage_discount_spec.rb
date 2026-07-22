require "rails_helper"

RSpec.describe Promotable::Actions::PercentageDiscount do
  before do
    @promo = create_promotion
    @action = described_class.create!(
      promotion: @promo,
      preferences: { percentage: 10 }
    )
    @order = create_order(total_amount: 200)
  end

  it "compute_amount returns negative percentage of promotable_amount" do
    amount = @action.compute_amount(@order)

    expect(amount).to eq(BigDecimal("-20"))
  end

  it "apply creates an adjustment" do
    expect { @action.apply(@order) }.to change(Promotable::Adjustment, :count).by(1)

    adjustment = Promotable::Adjustment.last
    expect(adjustment.amount).to eq(BigDecimal("-20"))
    expect(adjustment.label).to eq("10% discount")
    expect(adjustment.eligible?).to be(true)
  end

  it "apply does nothing when amount is zero" do
    order = create_order(total_amount: 0)

    expect { @action.apply(order) }.not_to change(Promotable::Adjustment, :count)
  end

  it "undo removes adjustments for the promotable" do
    @action.apply(@order)
    expect(Promotable::Adjustment.count).to eq(1)

    @action.undo(@order)

    expect(Promotable::Adjustment.count).to eq(0)
  end
end
