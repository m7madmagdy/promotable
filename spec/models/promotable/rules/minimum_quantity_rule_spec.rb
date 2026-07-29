require "rails_helper"

RSpec.describe Promotable::Rules::MinimumQuantityRule do
  let(:promo) { create_promotion }

  it "is eligible when item_count meets the minimum via promotable_item_count" do
    order = create_order(total_amount: 100, item_count: 5)
    order.define_singleton_method(:promotable_item_count) { 5 }
    rule = described_class.new(promotion: promo, preferences: { minimum_quantity: 3 })
    expect(rule.eligible?(order)).to be(true)
  end

  it "is ineligible when quantity is below the minimum" do
    order = create_order(total_amount: 100, item_count: 1)
    order.define_singleton_method(:promotable_item_count) { 1 }
    rule = described_class.new(promotion: promo, preferences: { minimum_quantity: 3 })
    expect(rule.eligible?(order)).to be(false)
  end

  it "falls back to items.size when item_count isn't implemented" do
    stub_promotable = Struct.new(:promotable_items).new([ :a, :b, :c, :d ])
    rule = described_class.new(promotion: promo, preferences: { minimum_quantity: 4 })
    expect(rule.eligible?(stub_promotable)).to be(true)
  end
end
