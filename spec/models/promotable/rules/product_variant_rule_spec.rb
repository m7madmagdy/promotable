require "rails_helper"

RSpec.describe Promotable::Rules::ProductVariantRule do
  let(:promo) { create_promotion }
  let(:order) { create_order(total_amount: 100) }

  before do
    variants = [ Struct.new(:variant_id).new(10), Struct.new(:variant_id).new(20) ]
    order.define_singleton_method(:promotable_items) { variants }
  end

  it "is eligible when include mode and at least one variant matches" do
    rule = described_class.new(promotion: promo, preferences: { variant_ids: [ 20, 99 ], mode: "include" })
    expect(rule.eligible?(order)).to be(true)
  end

  it "is ineligible when include mode and no variant matches" do
    rule = described_class.new(promotion: promo, preferences: { variant_ids: [ 99 ] })
    expect(rule.eligible?(order)).to be(false)
  end

  it "is ineligible when exclude mode and any listed variant is present" do
    rule = described_class.new(promotion: promo, preferences: { variant_ids: [ 10 ], mode: "exclude" })
    expect(rule.eligible?(order)).to be(false)
  end

  it "is eligible when exclude mode and none of the listed variants are present" do
    rule = described_class.new(promotion: promo, preferences: { variant_ids: [ 99 ], mode: "exclude" })
    expect(rule.eligible?(order)).to be(true)
  end
end
