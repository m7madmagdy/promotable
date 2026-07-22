require "rails_helper"

RSpec.describe Promotable::Actions::FreeShippingDiscount do
  before do
    @promo = create_promotion
    @action = described_class.create!(promotion: @promo)
    @order = create_order(shipping_cost: 15)
  end

  it "compute_amount returns negative shipping cost" do
    amount = @action.compute_amount(@order)

    expect(amount).to eq(BigDecimal("-15"))
  end

  it "compute_amount returns zero when no shipping cost method" do
    plain = Object.new
    def plain.promotable_amount
      BigDecimal("100")
    end

    amount = @action.compute_amount(plain)

    expect(amount).to eq(BigDecimal("0"))
  end

  it "apply creates an adjustment for shipping" do
    expect { @action.apply(@order) }.to change(Promotable::Adjustment, :count).by(1)

    adjustment = Promotable::Adjustment.last
    expect(adjustment.amount).to eq(BigDecimal("-15"))
    expect(adjustment.label).to eq("Free shipping")
  end

  it "apply does nothing when shipping cost is zero" do
    order = create_order(shipping_cost: 0)

    expect { @action.apply(order) }.not_to change(Promotable::Adjustment, :count)
  end
end
