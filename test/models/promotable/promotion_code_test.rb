require "test_helper"

class Promotable::PromotionCodeTest < ActiveSupport::TestCase
  test "validates code presence" do
    promo = create_promotion
    code = Promotable::PromotionCode.new(promotion: promo, code: nil)
    assert_not code.valid?
  end

  test "validates code uniqueness" do
    promo = create_promotion
    Promotable::PromotionCode.create!(promotion: promo, code: "UNIQUE1")
    duplicate = Promotable::PromotionCode.new(promotion: promo, code: "UNIQUE1")
    assert_not duplicate.valid?
  end

  test "normalizes code to uppercase by default" do
    promo = create_promotion
    code = Promotable::PromotionCode.create!(promotion: promo, code: "save10")
    assert_equal "SAVE10", code.code
  end

  test "preserves case when code_case_sensitive is true" do
    Promotable.configuration.code_case_sensitive = true
    promo = create_promotion
    code = Promotable::PromotionCode.create!(promotion: promo, code: "Save10")
    assert_equal "Save10", code.code
  end

  test "within_usage_limit? returns true when no limit" do
    promo = create_promotion
    code = Promotable::PromotionCode.create!(promotion: promo, code: "NOLIMIT")
    assert code.within_usage_limit?
  end

  test "within_usage_limit? returns false when limit reached" do
    promo = create_promotion
    code = Promotable::PromotionCode.create!(promotion: promo, code: "LIMITED", usage_limit: 1, usage_count: 1)
    assert_not code.within_usage_limit?
  end

  test "increment_usage! increases usage_count" do
    promo = create_promotion
    code = Promotable::PromotionCode.create!(promotion: promo, code: "INC")
    code.increment_usage!
    assert_equal 1, code.reload.usage_count
  end

  test "scope available returns codes within usage limit" do
    promo = create_promotion
    available = Promotable::PromotionCode.create!(promotion: promo, code: "AVAIL")
    Promotable::PromotionCode.create!(promotion: promo, code: "EXHAUSTED", usage_limit: 1, usage_count: 1)

    result = Promotable::PromotionCode.available
    assert_includes result, available
    assert_equal 1, result.count
  end
end
