require "rails_helper"

RSpec.describe Promotable::Rules::UserEligibilityRule do
  before do
    @promo = create_promotion
    @rule = described_class.create!(
      promotion: @promo,
      preferences: { eligible_group: "vip" }
    )
  end

  it "is eligible when user belongs to required group" do
    user = create_user(promotion_group: "vip")
    order = create_order

    expect(@rule.eligible?(order, user: user)).to be(true)
  end

  it "is ineligible when user belongs to a different group" do
    user = create_user(promotion_group: "regular")
    order = create_order

    expect(@rule.eligible?(order, user: user)).to be(false)
  end

  it "is ineligible when no user is provided" do
    order = create_order

    expect(@rule.eligible?(order)).to be(false)
  end
end
