require "rails_helper"

RSpec.describe Promotable::Rules::FrequencyRule do
  let(:promo) do
    promo = create_promotion
    Promotable::PromotionCode.create!(promotion: promo, code: "FREQ")
    promo
  end
  let(:order) { create_order(total_amount: 100) }

  it "is eligible when the user hasn't hit the max_uses ceiling" do
    user = create_user
    rule = described_class.new(promotion: promo, preferences: { max_uses: 3, period: "ever" })
    expect(rule.eligible?(order, user: user)).to be(true)
  end

  it "is ineligible once the user has reached max_uses in the period" do
    user = create_user
    code = promo.codes.first
    3.times do
      Promotable::CodeUsage.create!(
        promotion_code: code,
        user: user,
        promotable: create_order(total_amount: 10)
      )
    end
    rule = described_class.new(promotion: promo, preferences: { max_uses: 3, period: "ever" })
    expect(rule.eligible?(order, user: user)).to be(false)
  end

  it "resets the count at the start of each day when period=day" do
    user = create_user
    code = promo.codes.first
    # An old usage from yesterday shouldn't count
    Promotable::CodeUsage.create!(promotion_code: code, user: user, promotable: order)
      .update_column(:created_at, 2.days.ago)

    rule = described_class.new(promotion: promo, preferences: { max_uses: 1, period: "day" })
    expect(rule.eligible?(order, user: user)).to be(true)
  end
end
