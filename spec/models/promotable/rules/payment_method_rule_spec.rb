require "rails_helper"

RSpec.describe Promotable::Rules::PaymentMethodRule do
  let(:promo) { create_promotion }
  let(:order) { create_order(total_amount: 100) }
  let(:rule)  { described_class.new(promotion: promo, preferences: { methods: [ "wallet", "card" ] }) }

  it "is eligible when method matches (case-insensitive)" do
    order.define_singleton_method(:promotable_payment_method) { "WALLET" }
    expect(rule.eligible?(order)).to be(true)
  end

  it "is ineligible when method isn't listed" do
    order.define_singleton_method(:promotable_payment_method) { "cash" }
    expect(rule.eligible?(order)).to be(false)
  end
end
