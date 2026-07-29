require "rails_helper"

RSpec.describe Promotable::Rules::NewUserRule do
  let(:promo) { create_promotion }
  let(:order) { create_order(total_amount: 100) }
  let(:rule)  { described_class.new(promotion: promo, preferences: { within_days: 14 }) }

  it "is eligible when user was created within the window" do
    user = create_user
    user.update_column(:created_at, 5.days.ago)
    expect(rule.eligible?(order, user: user)).to be(true)
  end

  it "is ineligible when user is older than the window" do
    user = create_user
    user.update_column(:created_at, 30.days.ago)
    expect(rule.eligible?(order, user: user)).to be(false)
  end
end
