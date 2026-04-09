require "test_helper"

class Promotable::ApplicatorTest < ActiveSupport::TestCase
  setup do
    @order = create_order(total_amount: 100)
    @promo = create_promotion
    @action = Promotable::Actions::PercentageDiscount.create!(
      promotion: @promo,
      preferences: { percentage: 10 }
    )
  end

  test "apply creates adjustments from promotion actions" do
    applicator = Promotable::Applicator.new(@order)

    assert_difference "Promotable::Adjustment.count", 1 do
      applicator.apply([ @promo ])
    end
  end

  test "apply increments promotion usage_count" do
    applicator = Promotable::Applicator.new(@order)
    applicator.apply([ @promo ])

    assert_equal 1, @promo.reload.usage_count
  end

  test "apply respects max_promotions_per_promotable" do
    Promotable.configuration.max_promotions_per_promotable = 1

    promo2 = create_promotion(name: "Second", priority: 1)
    Promotable::Actions::FixedAmountDiscount.create!(
      promotion: promo2,
      preferences: { amount: 5 }
    )

    applicator = Promotable::Applicator.new(@order)
    applicator.apply([ @promo, promo2 ])

    promo_ids = Promotable::Adjustment.where(
      adjustable: @order
    ).pluck(:promotion_id).uniq

    assert_equal 1, promo_ids.size
  end

  test "remove_all destroys all adjustments for the promotable" do
    applicator = Promotable::Applicator.new(@order)
    applicator.apply([ @promo ])
    assert_equal 1, Promotable::Adjustment.count

    applicator.remove_all
    assert_equal 0, Promotable::Adjustment.count
  end

  test "apply does not duplicate already-applied promotions" do
    applicator = Promotable::Applicator.new(@order)
    applicator.apply([ @promo ])
    applicator.apply([ @promo ])

    assert_equal 1, Promotable::Adjustment.where(adjustable: @order, promotion: @promo).count
  end
end
