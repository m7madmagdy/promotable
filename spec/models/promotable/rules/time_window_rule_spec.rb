require "rails_helper"

RSpec.describe Promotable::Rules::TimeWindowRule do
  let(:promo) { create_promotion }
  let(:order) { create_order(total_amount: 100) }

  it "is eligible during an allowed day and hour" do
    monday_at_noon = Time.zone.local(2026, 7, 20, 12, 0, 0)
    travel_to(monday_at_noon) do
      rule = described_class.new(
        promotion: promo,
        preferences: { days_of_week: [ 1, 2, 3, 4, 5 ], start_hour: 9, end_hour: 17, time_zone: "UTC" }
      )
      expect(rule.eligible?(order)).to be(true)
    end
  end

  it "is ineligible outside the hour window" do
    monday_at_8am = Time.zone.local(2026, 7, 20, 8, 0, 0)
    travel_to(monday_at_8am) do
      rule = described_class.new(
        promotion: promo,
        preferences: { days_of_week: [ 1, 2, 3, 4, 5 ], start_hour: 9, end_hour: 17, time_zone: "UTC" }
      )
      expect(rule.eligible?(order)).to be(false)
    end
  end

  it "is ineligible on a disallowed weekday" do
    saturday_at_noon = Time.zone.local(2026, 7, 25, 12, 0, 0)
    travel_to(saturday_at_noon) do
      rule = described_class.new(
        promotion: promo,
        preferences: { days_of_week: [ 1, 2, 3, 4, 5 ], start_hour: 0, end_hour: 24, time_zone: "UTC" }
      )
      expect(rule.eligible?(order)).to be(false)
    end
  end
end
