require "rails_helper"

RSpec.describe Promotable::Applicator do
  before do
    @order = create_order(total_amount: 100)
    @promo = create_promotion
    Promotable::Actions::PercentageDiscount.create!(
      promotion: @promo,
      preferences: { percentage: 10 }
    )
  end

  it "apply creates adjustments from promotion actions" do
    applicator = described_class.new(@order)

    expect { applicator.apply([ @promo ]) }.to change(Promotable::Adjustment, :count).by(1)
  end

  it "apply increments promotion usage_count" do
    applicator = described_class.new(@order)

    applicator.apply([ @promo ])

    expect(@promo.reload.usage_count).to eq(1)
  end

  it "apply updates order total_after_discounts while keeping total_amount unchanged" do
    applicator = described_class.new(@order)

    applicator.apply([ @promo ])

    reloaded = @order.reload
    expect(reloaded.total_amount.to_d).to eq(BigDecimal("100.0"))
    expect(reloaded.total_after_discounts.to_d).to eq(BigDecimal("90.0"))
  end

  it "apply only applies one promotion when stacking is disabled" do
    promo2 = create_promotion(name: "Second", priority: 1)
    Promotable::Actions::PercentageDiscount.create!(
      promotion: promo2,
      preferences: { percentage: 5 }
    )

    applicator = described_class.new(@order)
    applicator.apply([ @promo, promo2 ])

    promo_ids = Promotable::Adjustment.where(adjustable: @order).pluck(:promotion_id).uniq

    expect(promo_ids.size).to eq(1)
  end

  it "remove_all destroys all adjustments for the promotable" do
    applicator = described_class.new(@order)
    applicator.apply([ @promo ])

    expect(Promotable::Adjustment.count).to eq(1)

    applicator.remove_all

    expect(Promotable::Adjustment.count).to eq(0)
    expect(@order.reload.total_after_discounts.to_d).to eq(BigDecimal("100.0"))
  end

  it "remove restores order total_after_discounts when a promotion is removed" do
    applicator = described_class.new(@order)
    applicator.apply([ @promo ])

    applicator.remove(@promo)

    expect(@order.reload.total_after_discounts.to_d).to eq(BigDecimal("100.0"))
  end

  it "apply does not duplicate already applied promotions" do
    applicator = described_class.new(@order)

    applicator.apply([ @promo ])
    applicator.apply([ @promo ])

    count = Promotable::Adjustment.where(adjustable: @order, promotion: @promo).count
    expect(count).to eq(1)
  end
end
