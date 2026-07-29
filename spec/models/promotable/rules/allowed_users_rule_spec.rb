require "rails_helper"

RSpec.describe Promotable::Rules::AllowedUsersRule do
  let(:promo) { create_promotion }
  let(:order) { create_order(total_amount: 100) }

  it "is eligible when the user's id is in the allow-list" do
    user = create_user
    rule = described_class.new(promotion: promo, preferences: { user_ids: [ user.id ] })
    expect(rule.eligible?(order, user: user)).to be(true)
  end

  it "is ineligible when the user's id is not listed" do
    user = create_user
    rule = described_class.new(promotion: promo, preferences: { user_ids: [ user.id + 999 ] })
    expect(rule.eligible?(order, user: user)).to be(false)
  end

  it "matches by promotion group when the id list doesn't hit" do
    user = create_user(promotion_group: "vip")
    rule = described_class.new(promotion: promo, preferences: { user_group: "vip" })
    expect(rule.eligible?(order, user: user)).to be(true)
  end
end
