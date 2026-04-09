require "test_helper"

class Promotable::Rules::FirstPurchaseRuleTest < ActiveSupport::TestCase
  setup do
    @promo = create_promotion
    @rule = Promotable::Rules::FirstPurchaseRule.create!(promotion: @promo)
  end

  test "eligible for user with no prior usages" do
    user = create_user
    order = create_order
    assert @rule.eligible?(order, user: user)
  end

  test "ineligible for user with existing usages" do
    user = create_user
    order = create_order
    code = Promotable::PromotionCode.create!(promotion: @promo, code: "FIRST")
    Promotable::CodeUsage.create!(
      promotion_code: code,
      user: user,
      promotable: order
    )

    assert_not @rule.eligible?(order, user: user)
  end

  test "ineligible when no user provided" do
    order = create_order
    assert_not @rule.eligible?(order)
  end
end
