require "rails_helper"

RSpec.describe Promotable::Rules::FirstPurchaseRule do
  let(:promo) { create_promotion }
  let(:order) { create_order(total_amount: 100) }
  let(:user)  { create_user }
  let(:rule)  { described_class.new(promotion: promo) }

  it "is eligible when the user has zero prior promotable orders" do
    user.define_singleton_method(:promotable_order_count) { 0 }
    expect(rule.eligible?(order, user: user)).to be(true)
  end

  it "is ineligible when the user has prior orders" do
    user.define_singleton_method(:promotable_order_count) { 5 }
    expect(rule.eligible?(order, user: user)).to be(false)
  end

  it "raises MissingContextError when :user is not in context" do
    expect { rule.eligible?(order) }.to raise_error(Promotable::MissingContextError, /:user/)
  end
end
