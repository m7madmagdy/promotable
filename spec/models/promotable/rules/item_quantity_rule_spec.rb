require "rails_helper"

RSpec.describe Promotable::Rules::ItemQuantityRule do
  before do
    @promo = create_promotion
    @rule = described_class.create!(
      promotion: @promo,
      preferences: { minimum_quantity: 3 }
    )
  end

  it "is eligible when item count meets minimum" do
    order = create_order(item_count: 5)

    expect(@rule.eligible?(order)).to be(true)
  end

  it "is eligible when item count equals minimum" do
    order = create_order(item_count: 3)

    expect(@rule.eligible?(order)).to be(true)
  end

  it "is ineligible when item count is below minimum" do
    order = create_order(item_count: 1)

    expect(@rule.eligible?(order)).to be(false)
  end

  it "is ineligible when promotable does not respond to promotable_items" do
    promotable = Object.new

    expect(@rule.eligible?(promotable)).to be(false)
  end
end
