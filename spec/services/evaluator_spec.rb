require "rails_helper"

RSpec.describe Promotable::Evaluator do
  before do
    @order = create_order(total_amount: 100)
  end

  it "eligible_promotions returns active and current promotions" do
    promo = create_promotion(active: true)
    create_promotion(name: "Inactive", active: false)

    evaluator = described_class.new(@order)
    result = evaluator.eligible_promotions

    expect(result).to include(promo)
    expect(result.size).to eq(1)
  end

  it "eligible_promotions filters by rules" do
    promo = create_promotion
    promo.rules.create!(
      type: "Promotable::Rules::MinimumAmountRule",
      preferences: { minimum_amount: 200 }
    )

    evaluator = described_class.new(@order)

    expect(evaluator.eligible_promotions).to be_empty
  end

  it "eligible_promotions with code finds matching promotion" do
    promo = create_promotion_with_code(code: "VIP20")

    evaluator = described_class.new(@order, code: "VIP20")
    result = evaluator.eligible_promotions

    expect(result).to include(promo)
  end

  it "eligible_promotions with invalid code returns empty" do
    evaluator = described_class.new(@order, code: "BADCODE")

    expect(evaluator.eligible_promotions).to be_empty
  end

  it "best_promotion returns highest-priority promotion" do
    create_promotion(name: "Low Priority", priority: 10)
    high = create_promotion(name: "High Priority", priority: 1)

    evaluator = described_class.new(@order)

    expect(evaluator.best_promotion).to eq(high)
  end

  it "best_promotion returns nil when none are eligible" do
    evaluator = described_class.new(@order)

    expect(evaluator.best_promotion).to be_nil
  end

  it "eligible_promotions includes global and matching-client promotions" do
    acme = create_client(name: "Acme")
    Promotable.configuration.current_tenant_resolver = -> { acme }

    global = create_promotion(name: "Global")
    acme_promo = create_promotion(name: "Acme", client: acme)

    evaluator = described_class.new(@order)

    expect(evaluator.eligible_promotions).to include(global, acme_promo)
  end

  it "eligible_promotions excludes other-client promotions" do
    acme = create_client(name: "Acme")
    globex = create_client(name: "Globex")
    Promotable.configuration.current_tenant_resolver = -> { acme }

    create_promotion(name: "Globex", client: globex)

    evaluator = described_class.new(@order)

    expect(evaluator.eligible_promotions.map(&:name)).not_to include("Globex")
  end
end
