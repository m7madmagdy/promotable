require "rails_helper"

RSpec.describe Promotable::Actions::FreeShippingAction do
  let(:promo) { create_promotion }
  let(:order) { create_order(total_amount: 100, shipping_cost: 12) }
  let(:action) { described_class.create!(promotion: promo) }

  it "computes a negative adjustment equal to shipping_cost" do
    expect(action.compute_amount(order)).to eq(BigDecimal("-12"))
  end

  it "creates a 'Free shipping' adjustment" do
    action.apply(order)
    adjustment = Promotable::Adjustment.last
    expect(adjustment.amount).to eq(BigDecimal("-12"))
    expect(adjustment.label).to eq("Free shipping")
  end

  it "does nothing when shipping is zero" do
    free_order = create_order(total_amount: 100, shipping_cost: 0)
    expect { action.apply(free_order) }.not_to change(Promotable::Adjustment, :count)
  end
end
