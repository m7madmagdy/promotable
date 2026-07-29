require "rails_helper"

RSpec.describe Promotable::Rules::UserActivityRule do
  let(:promo) { create_promotion }
  let(:order) { create_order(total_amount: 100) }
  let(:user)  { create_user }

  it "is eligible when both order-count and recency bounds are met" do
    user.define_singleton_method(:promotable_order_count) { 3 }
    user.define_singleton_method(:promotable_last_order_at) { 2.days.ago }
    rule = described_class.new(
      promotion: promo,
      preferences: { min_orders: 1, max_orders: 10, max_days_since_last: 7 }
    )
    expect(rule.eligible?(order, user: user)).to be(true)
  end

  it "is ineligible when order count is below the minimum" do
    user.define_singleton_method(:promotable_order_count) { 0 }
    rule = described_class.new(promotion: promo, preferences: { min_orders: 3 })
    expect(rule.eligible?(order, user: user)).to be(false)
  end

  it "is ineligible when the last order is too stale" do
    user.define_singleton_method(:promotable_last_order_at) { 90.days.ago }
    rule = described_class.new(promotion: promo, preferences: { max_days_since_last: 30 })
    expect(rule.eligible?(order, user: user)).to be(false)
  end
end
