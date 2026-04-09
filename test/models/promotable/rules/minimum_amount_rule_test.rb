require "test_helper"

class Promotable::Rules::MinimumAmountRuleTest < ActiveSupport::TestCase
  setup do
    @promo = create_promotion
    @rule = Promotable::Rules::MinimumAmountRule.create!(
      promotion: @promo,
      preferences: { minimum_amount: 50 }
    )
  end

  test "eligible when order amount meets minimum" do
    order = create_order(total_amount: 100)
    assert @rule.eligible?(order)
  end

  test "eligible when order amount equals minimum" do
    order = create_order(total_amount: 50)
    assert @rule.eligible?(order)
  end

  test "ineligible when order amount is below minimum" do
    order = create_order(total_amount: 30)
    assert_not @rule.eligible?(order)
  end

  test "preference_fields returns minimum_amount field" do
    fields = Promotable::Rules::MinimumAmountRule.preference_fields
    assert_equal 1, fields.size
    assert_equal :minimum_amount, fields.first[:name]
  end
end
