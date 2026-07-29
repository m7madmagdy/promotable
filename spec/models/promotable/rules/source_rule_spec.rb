require "rails_helper"

RSpec.describe Promotable::Rules::SourceRule do
  let(:promo) { create_promotion }
  let(:order) { create_order(total_amount: 100) }
  let(:rule)  { described_class.new(promotion: promo, preferences: { sources: [ "web", "ios" ] }) }

  it "is eligible when source is in the allow-list" do
    order.define_singleton_method(:promotable_source) { "IOS" }
    expect(rule.eligible?(order)).to be(true)
  end

  it "is ineligible when source isn't listed" do
    order.define_singleton_method(:promotable_source) { "kiosk" }
    expect(rule.eligible?(order)).to be(false)
  end
end
