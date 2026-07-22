require "rails_helper"

RSpec.describe Promotable::Configuration do
  it "has default configuration values" do
    config = described_class.new

    expect(config.max_promotions_per_promotable).to eq(5)
    expect(config.allow_stacking).to be(true)
    expect(config.code_case_sensitive).to be(false)
  end

  it "sets values through configure block" do
    Promotable.configure do |config|
      config.max_promotions_per_promotable = 3
      config.allow_stacking = false
    end

    expect(Promotable.configuration.max_promotions_per_promotable).to eq(3)
    expect(Promotable.configuration.allow_stacking).to be(false)
  end

  it "restores defaults with reset_configuration!" do
    Promotable.configure do |config|
      config.max_promotions_per_promotable = 1
    end

    Promotable.reset_configuration!

    expect(Promotable.configuration.max_promotions_per_promotable).to eq(5)
  end

  it "registers built-in rules and actions" do
    config = described_class.new
    config.register_defaults!

    expect(config.rule_registry.registered?(:minimum_amount)).to be(true)
    expect(config.rule_registry.registered?(:item_quantity)).to be(true)
    expect(config.rule_registry.registered?(:first_purchase)).to be(true)
    expect(config.rule_registry.registered?(:user_eligibility)).to be(true)

    expect(config.action_registry.registered?(:percentage_discount)).to be(true)
    expect(config.action_registry.registered?(:fixed_amount_discount)).to be(true)
    expect(config.action_registry.registered?(:free_shipping_discount)).to be(true)
  end
end
