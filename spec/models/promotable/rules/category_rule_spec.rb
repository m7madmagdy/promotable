require "rails_helper"

RSpec.describe Promotable::Rules::CategoryRule do
  let(:promo) { create_promotion }
  let(:order) { create_order(total_amount: 100) }

  before do
    items = [ Struct.new(:category_id).new(1), Struct.new(:category_id).new(2) ]
    order.define_singleton_method(:promotable_items) { items }
  end

  it "is eligible when include mode and at least one category matches" do
    rule = described_class.new(promotion: promo, preferences: { category_ids: [ 2, 99 ] })
    expect(rule.eligible?(order)).to be(true)
  end

  it "is ineligible when include mode and no category matches" do
    rule = described_class.new(promotion: promo, preferences: { category_ids: [ 99 ] })
    expect(rule.eligible?(order)).to be(false)
  end

  it "is ineligible when exclude mode and any listed category is present" do
    rule = described_class.new(promotion: promo, preferences: { category_ids: [ 1 ], mode: "exclude" })
    expect(rule.eligible?(order)).to be(false)
  end
end
