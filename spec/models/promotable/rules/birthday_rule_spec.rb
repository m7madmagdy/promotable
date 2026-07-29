require "rails_helper"

RSpec.describe Promotable::Rules::BirthdayRule do
  let(:promo) { create_promotion }
  let(:order) { create_order(total_amount: 100) }
  let(:user)  { create_user }

  it "is eligible on the user's birthday" do
    travel_to(Date.new(2026, 7, 20)) do
      user.define_singleton_method(:birthday) { Date.new(1990, 7, 20) }
      rule = described_class.new(promotion: promo)
      expect(rule.eligible?(order, user: user)).to be(true)
    end
  end

  it "is ineligible on a different day" do
    travel_to(Date.new(2026, 7, 20)) do
      user.define_singleton_method(:birthday) { Date.new(1990, 12, 25) }
      rule = described_class.new(promotion: promo)
      expect(rule.eligible?(order, user: user)).to be(false)
    end
  end

  it "honors window_days for a symmetric grace period" do
    travel_to(Date.new(2026, 7, 22)) do
      user.define_singleton_method(:birthday) { Date.new(1990, 7, 20) }
      rule = described_class.new(promotion: promo, preferences: { window_days: 3 })
      expect(rule.eligible?(order, user: user)).to be(true)
    end
  end
end
