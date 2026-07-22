require "rails_helper"

RSpec.describe Promotable::CodeRedeemer do
  before do
    @promo = create_promotion
    @code = Promotable::PromotionCode.create!(promotion: @promo, code: "SAVE10")
    Promotable::Actions::PercentageDiscount.create!(
      promotion: @promo,
      preferences: { percentage: 10 }
    )
    @order = create_order(total_amount: 100)
    @user = create_user
  end

  it "redeem applies promotion and records usage" do
    redeemer = described_class.new("SAVE10", promotable: @order, user: @user)

    expect { redeemer.redeem }
      .to change(Promotable::Adjustment, :count).by(1)
      .and change(Promotable::CodeUsage, :count).by(1)
  end

  it "redeem increments code usage_count" do
    redeemer = described_class.new("SAVE10", promotable: @order, user: @user)

    redeemer.redeem

    expect(@code.reload.usage_count).to eq(1)
  end

  it "redeem normalizes code to uppercase" do
    redeemer = described_class.new("save10", promotable: @order, user: @user)

    expect { redeemer.redeem }.to change(Promotable::Adjustment, :count).by(1)
  end

  it "redeem raises InvalidCodeError for unknown code" do
    redeemer = described_class.new("UNKNOWN", promotable: @order, user: @user)

    expect { redeemer.redeem }.to raise_error(Promotable::InvalidCodeError)
  end

  it "redeem raises PromotionInactiveError for inactive promotion" do
    @promo.update!(active: false)
    redeemer = described_class.new("SAVE10", promotable: @order, user: @user)

    expect { redeemer.redeem }.to raise_error(Promotable::PromotionInactiveError)
  end

  it "redeem raises PromotionExpiredError for expired promotion" do
    @promo.update!(starts_at: 3.days.ago, expires_at: 1.day.ago)
    redeemer = described_class.new("SAVE10", promotable: @order, user: @user)

    expect { redeemer.redeem }.to raise_error(Promotable::PromotionExpiredError)
  end

  it "redeem raises UsageLimitExceededError when code limit is reached" do
    @code.update!(usage_limit: 1, usage_count: 1)
    redeemer = described_class.new("SAVE10", promotable: @order, user: @user)

    expect { redeemer.redeem }.to raise_error(Promotable::UsageLimitExceededError)
  end

  it "redeem raises UsageLimitExceededError for per-user limit" do
    @promo.update!(per_user_limit: 1)
    Promotable::CodeUsage.create!(
      promotion_code: @code,
      user: @user,
      promotable: create_order
    )

    redeemer = described_class.new("SAVE10", promotable: @order, user: @user)

    expect { redeemer.redeem }.to raise_error(Promotable::UsageLimitExceededError)
  end

  it "redeem works without a user and does not track code usage" do
    redeemer = described_class.new("SAVE10", promotable: @order)

    expect { redeemer.redeem }
      .to change(Promotable::Adjustment, :count).by(1)
      .and change(Promotable::CodeUsage, :count).by(0)
  end
end
