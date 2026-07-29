require "rails_helper"

RSpec.describe Promotable::Rules::CountryRule do
  let(:promo) { create_promotion }
  let(:order) { create_order(total_amount: 100) }
  let(:rule)  { described_class.new(promotion: promo, preferences: { countries: [ "US", "CA" ] }) }

  it "is eligible when country matches (case-insensitive)" do
    order.define_singleton_method(:promotable_country) { "us" }
    expect(rule.eligible?(order)).to be(true)
  end

  it "is ineligible when country isn't listed" do
    order.define_singleton_method(:promotable_country) { "FR" }
    expect(rule.eligible?(order)).to be(false)
  end

  it "is ineligible when the host doesn't provide a country" do
    expect(rule.eligible?(order)).to be(false)
  end
end
