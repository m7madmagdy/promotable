require "rails_helper"

RSpec.describe Promotable::Promotion do
  it "validates name presence" do
    promo = described_class.new(name: nil)

    expect(promo).not_to be_valid
    expect(promo.errors[:name]).to include("can't be blank")
  end

  it "validates expires_at is after starts_at" do
    promo = described_class.new(
      name: "Bad dates",
      starts_at: 1.day.from_now,
      expires_at: 1.day.ago
    )

    expect(promo).not_to be_valid
    expect(promo.errors[:expires_at]).to include("must be after starts_at")
  end

  it "active scope returns only active promotions" do
    active = create_promotion(active: true)
    create_promotion(name: "Inactive", active: false)

    expect(described_class.active).to include(active)
    expect(described_class.active.count).to eq(1)
  end

  it "current scope returns only in-date promotions" do
    current = create_promotion(starts_at: 1.day.ago, expires_at: 1.day.from_now)
    create_promotion(name: "Expired", starts_at: 3.days.ago, expires_at: 1.day.ago)

    expect(described_class.current).to include(current)
  end

  it "available scope combines active and current" do
    promo = create_promotion(active: true, starts_at: 1.day.ago, expires_at: 1.day.from_now)
    create_promotion(name: "Inactive", active: false)
    create_promotion(name: "Expired", active: true, starts_at: 3.days.ago, expires_at: 1.day.ago)

    available = described_class.available

    expect(available).to include(promo)
    expect(available.count).to eq(1)
  end

  it "within_date_range? returns true when no dates are set" do
    promo = create_promotion(starts_at: nil, expires_at: nil)

    expect(promo.within_date_range?).to be(true)
  end

  it "within_usage_limit? returns true when no limit" do
    promo = create_promotion(usage_limit: nil)

    expect(promo.within_usage_limit?).to be(true)
  end

  it "within_usage_limit? returns false when limit is reached" do
    promo = create_promotion(usage_limit: 1, usage_count: 1)

    expect(promo.within_usage_limit?).to be(false)
  end

  it "increment_usage! increments usage_count" do
    promo = create_promotion(usage_count: 0)

    promo.increment_usage!

    expect(promo.reload.usage_count).to eq(1)
  end

  it "eligible? checks all conditions" do
    promo = create_promotion(active: true)
    order = create_order

    expect(promo.eligible?(order)).to be(true)
  end

  it "eligible? returns false when inactive" do
    promo = create_promotion(active: false)
    order = create_order

    expect(promo.eligible?(order)).to be(false)
  end

  it "eligible? returns false when expired" do
    promo = create_promotion(starts_at: 3.days.ago, expires_at: 1.day.ago)
    order = create_order

    expect(promo.eligible?(order)).to be(false)
  end

  it "eligible? checks rules" do
    promo = create_promotion
    promo.rules.create!(
      type: "Promotable::Rules::MinimumAmountRule",
      preferences: { minimum_amount: 200 }
    )
    order = create_order(total_amount: 100)

    expect(promo.eligible?(order)).to be(false)
  end
end
