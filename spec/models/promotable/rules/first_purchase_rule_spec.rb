require "rails_helper"

RSpec.describe Promotable::Rules::FirstPurchaseRule do
  before do
    @promo = create_promotion
    @rule = described_class.create!(promotion: @promo)
  end

  it "is eligible for user with no prior usages" do
    user = create_user
    order = create_order

    expect(@rule.eligible?(order, user: user)).to be(true)
  end

  it "is ineligible for user with existing usages" do
    user = create_user
    order = create_order
    code = Promotable::PromotionCode.create!(promotion: @promo, code: "FIRST")
    Promotable::CodeUsage.create!(
      promotion_code: code,
      user: user,
      promotable: order
    )

    expect(@rule.eligible?(order, user: user)).to be(false)
  end

  it "is ineligible when no user is provided" do
    order = create_order

    expect(@rule.eligible?(order)).to be(false)
  end
end
