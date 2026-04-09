require "test_helper"

class Promotable::CodeRedeemerTest < ActiveSupport::TestCase
  setup do
    @promo = create_promotion
    @code = Promotable::PromotionCode.create!(promotion: @promo, code: "SAVE10")
    Promotable::Actions::PercentageDiscount.create!(
      promotion: @promo,
      preferences: { percentage: 10 }
    )
    @order = create_order(total_amount: 100)
    @user = create_user
  end

  test "redeem applies the promotion and records usage" do
    redeemer = Promotable::CodeRedeemer.new("SAVE10", promotable: @order, user: @user)

    assert_difference [ "Promotable::Adjustment.count", "Promotable::CodeUsage.count" ], 1 do
      redeemer.redeem
    end
  end

  test "redeem increments code usage_count" do
    redeemer = Promotable::CodeRedeemer.new("SAVE10", promotable: @order, user: @user)
    redeemer.redeem

    assert_equal 1, @code.reload.usage_count
  end

  test "redeem normalizes code to uppercase" do
    redeemer = Promotable::CodeRedeemer.new("save10", promotable: @order, user: @user)

    assert_difference "Promotable::Adjustment.count", 1 do
      redeemer.redeem
    end
  end

  test "redeem raises InvalidCodeError for unknown code" do
    redeemer = Promotable::CodeRedeemer.new("UNKNOWN", promotable: @order, user: @user)

    assert_raises Promotable::InvalidCodeError do
      redeemer.redeem
    end
  end

  test "redeem raises PromotionInactiveError for inactive promotion" do
    @promo.update!(active: false)
    redeemer = Promotable::CodeRedeemer.new("SAVE10", promotable: @order, user: @user)

    assert_raises Promotable::PromotionInactiveError do
      redeemer.redeem
    end
  end

  test "redeem raises PromotionExpiredError for expired promotion" do
    @promo.update!(starts_at: 3.days.ago, expires_at: 1.day.ago)
    redeemer = Promotable::CodeRedeemer.new("SAVE10", promotable: @order, user: @user)

    assert_raises Promotable::PromotionExpiredError do
      redeemer.redeem
    end
  end

  test "redeem raises UsageLimitExceededError when code limit reached" do
    @code.update!(usage_limit: 1, usage_count: 1)
    redeemer = Promotable::CodeRedeemer.new("SAVE10", promotable: @order, user: @user)

    assert_raises Promotable::UsageLimitExceededError do
      redeemer.redeem
    end
  end

  test "redeem raises UsageLimitExceededError for per-user limit" do
    @promo.update!(per_user_limit: 1)
    Promotable::CodeUsage.create!(
      promotion_code: @code,
      user: @user,
      promotable: create_order
    )

    redeemer = Promotable::CodeRedeemer.new("SAVE10", promotable: @order, user: @user)

    assert_raises Promotable::UsageLimitExceededError do
      redeemer.redeem
    end
  end

  test "redeem works without a user (no usage tracking)" do
    redeemer = Promotable::CodeRedeemer.new("SAVE10", promotable: @order)

    assert_difference "Promotable::Adjustment.count", 1 do
      assert_no_difference "Promotable::CodeUsage.count" do
        redeemer.redeem
      end
    end
  end
end
