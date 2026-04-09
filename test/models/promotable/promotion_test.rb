require "test_helper"

class Promotable::PromotionTest < ActiveSupport::TestCase
  test "validates name presence" do
    promo = Promotable::Promotion.new(name: nil)
    assert_not promo.valid?
    assert_includes promo.errors[:name], "can't be blank"
  end

  test "validates expires_at is after starts_at" do
    promo = Promotable::Promotion.new(
      name: "Bad dates",
      starts_at: 1.day.from_now,
      expires_at: 1.day.ago
    )
    assert_not promo.valid?
    assert_includes promo.errors[:expires_at], "must be after starts_at"
  end

  test "scope active returns only active promotions" do
    active = create_promotion(active: true)
    create_promotion(name: "Inactive", active: false)

    assert_includes Promotable::Promotion.active, active
    assert_equal 1, Promotable::Promotion.active.count
  end

  test "scope current returns only in-date promotions" do
    current = create_promotion(starts_at: 1.day.ago, expires_at: 1.day.from_now)
    create_promotion(name: "Expired", starts_at: 3.days.ago, expires_at: 1.day.ago)

    assert_includes Promotable::Promotion.current, current
  end

  test "scope available combines active and current" do
    promo = create_promotion(active: true, starts_at: 1.day.ago, expires_at: 1.day.from_now)
    create_promotion(name: "Inactive", active: false)
    create_promotion(name: "Expired", active: true, starts_at: 3.days.ago, expires_at: 1.day.ago)

    available = Promotable::Promotion.available
    assert_includes available, promo
    assert_equal 1, available.count
  end

  test "within_date_range? returns true when no dates set" do
    promo = create_promotion(starts_at: nil, expires_at: nil)
    assert promo.within_date_range?
  end

  test "within_usage_limit? returns true when no limit" do
    promo = create_promotion(usage_limit: nil)
    assert promo.within_usage_limit?
  end

  test "within_usage_limit? returns false when limit reached" do
    promo = create_promotion(usage_limit: 1, usage_count: 1)
    assert_not promo.within_usage_limit?
  end

  test "increment_usage! increments usage_count" do
    promo = create_promotion(usage_count: 0)
    promo.increment_usage!
    assert_equal 1, promo.reload.usage_count
  end

  test "eligible? checks all conditions" do
    promo = create_promotion(active: true)
    order = create_order

    assert promo.eligible?(order)
  end

  test "eligible? returns false when inactive" do
    promo = create_promotion(active: false)
    order = create_order

    assert_not promo.eligible?(order)
  end

  test "eligible? returns false when expired" do
    promo = create_promotion(starts_at: 3.days.ago, expires_at: 1.day.ago)
    order = create_order

    assert_not promo.eligible?(order)
  end

  test "eligible? checks rules" do
    promo = create_promotion
    promo.rules.create!(
      type: "Promotable::Rules::MinimumAmountRule",
      preferences: { minimum_amount: 200 }
    )
    order = create_order(total_amount: 100)

    assert_not promo.eligible?(order)
  end
end
