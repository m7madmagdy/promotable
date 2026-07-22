require "rails_helper"

RSpec.describe Promotable::PromotionCode do
  it "validates code presence" do
    promo = create_promotion
    code = described_class.new(promotion: promo, code: nil)

    expect(code).not_to be_valid
  end

  it "validates code uniqueness" do
    promo = create_promotion
    described_class.create!(promotion: promo, code: "UNIQUE1")
    duplicate = described_class.new(promotion: promo, code: "UNIQUE1")

    expect(duplicate).not_to be_valid
  end

  it "preserves case by default" do
    promo = create_promotion
    code = described_class.create!(promotion: promo, code: "save10")

    expect(code.code).to eq("save10")
  end

  it "normalizes code to uppercase when code_case_sensitive is false" do
    Promotable.configuration.code_case_sensitive = false
    promo = create_promotion
    code = described_class.create!(promotion: promo, code: "Save10")

    expect(code.code).to eq("SAVE10")
  end

  it "within_usage_limit? returns true when no limit" do
    promo = create_promotion
    code = described_class.create!(promotion: promo, code: "NOLIMIT")

    expect(code.within_usage_limit?).to be(true)
  end

  it "within_usage_limit? returns false when limit is reached" do
    promo = create_promotion
    code = described_class.create!(promotion: promo, code: "LIMITED", usage_limit: 1, usage_count: 1)

    expect(code.within_usage_limit?).to be(false)
  end

  it "increment_usage! increases usage_count" do
    promo = create_promotion
    code = described_class.create!(promotion: promo, code: "INC")

    code.increment_usage!

    expect(code.reload.usage_count).to eq(1)
  end

  it "available scope returns codes within usage limit" do
    promo = create_promotion
    available = described_class.create!(promotion: promo, code: "AVAIL")
    described_class.create!(promotion: promo, code: "EXHAUSTED", usage_limit: 1, usage_count: 1)

    result = described_class.available

    expect(result).to include(available)
    expect(result.count).to eq(1)
  end
end
