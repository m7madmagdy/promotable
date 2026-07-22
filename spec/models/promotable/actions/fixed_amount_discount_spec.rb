require "rails_helper"

RSpec.describe Promotable::Actions::FixedAmountDiscount do
  before do
    @promo = create_promotion
    @action = described_class.create!(
      promotion: @promo,
      preferences: { amount: 15 }
    )
    @order = create_order(total_amount: 100)
  end

  it "compute_amount returns negative fixed amount" do
    amount = @action.compute_amount(@order)

    expect(amount).to eq(BigDecimal("-15"))
  end

  it "compute_amount caps discount at promotable_amount" do
    small_order = create_order(total_amount: 10)
    amount = @action.compute_amount(small_order)

    expect(amount).to eq(BigDecimal("-10"))
  end

  it "apply creates an adjustment" do
    expect { @action.apply(@order) }.to change(Promotable::Adjustment, :count).by(1)

    adjustment = Promotable::Adjustment.last
    expect(adjustment.amount).to eq(BigDecimal("-15"))
  end

  it "apply does nothing when amount would be zero" do
    order = create_order(total_amount: 0)

    expect { @action.apply(order) }.not_to change(Promotable::Adjustment, :count)
  end
end
