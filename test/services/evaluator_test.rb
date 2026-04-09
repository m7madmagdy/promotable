require "test_helper"

class Promotable::EvaluatorTest < ActiveSupport::TestCase
  setup do
    @order = create_order(total_amount: 100)
  end

  test "eligible_promotions returns active, current promotions" do
    promo = create_promotion(active: true)
    create_promotion(name: "Inactive", active: false)

    evaluator = Promotable::Evaluator.new(@order)
    result = evaluator.eligible_promotions

    assert_includes result, promo
    assert_equal 1, result.size
  end

  test "eligible_promotions filters by rules" do
    promo = create_promotion
    promo.rules.create!(
      type: "Promotable::Rules::MinimumAmountRule",
      preferences: { minimum_amount: 200 }
    )

    evaluator = Promotable::Evaluator.new(@order)
    assert_empty evaluator.eligible_promotions
  end

  test "eligible_promotions with code finds the matching promotion" do
    promo = create_promotion_with_code(code: "VIP20")

    evaluator = Promotable::Evaluator.new(@order, code: "VIP20")
    result = evaluator.eligible_promotions

    assert_includes result, promo
  end

  test "eligible_promotions with invalid code returns empty" do
    evaluator = Promotable::Evaluator.new(@order, code: "BADCODE")
    assert_empty evaluator.eligible_promotions
  end

  test "best_promotion returns the highest-priority promotion" do
    create_promotion(name: "Low Priority", priority: 10)
    high = create_promotion(name: "High Priority", priority: 1)

    evaluator = Promotable::Evaluator.new(@order)
    assert_equal high, evaluator.best_promotion
  end

  test "best_promotion returns nil when none eligible" do
    evaluator = Promotable::Evaluator.new(@order)
    assert_nil evaluator.best_promotion
  end
end
