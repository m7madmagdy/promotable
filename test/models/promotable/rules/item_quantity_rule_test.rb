require "test_helper"

class Promotable::Rules::ItemQuantityRuleTest < ActiveSupport::TestCase
  setup do
    @promo = create_promotion
    @rule = Promotable::Rules::ItemQuantityRule.create!(
      promotion: @promo,
      preferences: { minimum_quantity: 3 }
    )
  end

  test "eligible when item count meets minimum" do
    order = create_order(item_count: 5)
    assert @rule.eligible?(order)
  end

  test "eligible when item count equals minimum" do
    order = create_order(item_count: 3)
    assert @rule.eligible?(order)
  end

  test "ineligible when item count is below minimum" do
    order = create_order(item_count: 1)
    assert_not @rule.eligible?(order)
  end

  test "ineligible when promotable does not respond to promotable_items" do
    promotable = Object.new
    assert_not @rule.eligible?(promotable)
  end
end
