require "rails_helper"

RSpec.describe Promotable::Rules::StoreRule do
  let(:promo) { create_promotion }
  let(:order) { create_order(total_amount: 100) }
  let(:rule)  { described_class.new(promotion: promo, preferences: { store_ids: [ 1, 2, 3 ] }) }

  it "is eligible when store id is in the allow-list" do
    order.define_singleton_method(:promotable_store_id) { 2 }
    expect(rule.eligible?(order)).to be(true)
  end

  it "is ineligible when store id is not listed" do
    order.define_singleton_method(:promotable_store_id) { 99 }
    expect(rule.eligible?(order)).to be(false)
  end
end
