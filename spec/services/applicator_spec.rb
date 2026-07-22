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

  it "apply respects max_promotions_per_promotable" do
    Promotable.configuration.max_promotions_per_promotable = 1

    promo2 = create_promotion(name: "Second", priority: 1)
    Promotable::Actions::FixedAmountDiscount.create!(
      promotion: promo2,
      preferences: { amount: 5 }
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
  end

  it "apply does not duplicate already applied promotions" do
    applicator = described_class.new(@order)

    applicator.apply([ @promo ])
    applicator.apply([ @promo ])

    count = Promotable::Adjustment.where(adjustable: @order, promotion: @promo).count
    expect(count).to eq(1)
  end
end
