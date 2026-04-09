require "test_helper"

class Promotable::Rules::UserEligibilityRuleTest < ActiveSupport::TestCase
  setup do
    @promo = create_promotion
    @rule = Promotable::Rules::UserEligibilityRule.create!(
      promotion: @promo,
      preferences: { eligible_group: "vip" }
    )
  end

  test "eligible when user belongs to the required group" do
    user = create_user(promotion_group: "vip")
    order = create_order
    assert @rule.eligible?(order, user: user)
  end

  test "ineligible when user belongs to a different group" do
    user = create_user(promotion_group: "regular")
    order = create_order
    assert_not @rule.eligible?(order, user: user)
  end

  test "ineligible when no user provided" do
    order = create_order
    assert_not @rule.eligible?(order)
  end
end
