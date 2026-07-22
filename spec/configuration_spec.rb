require "rails_helper"

RSpec.describe Promotable::Configuration do
  it "has default configuration values" do
    config = described_class.new

    expect(config.allow_stacking).to be(false)
    expect(config.code_case_sensitive).to be(true)
    expect(config.tenant_model_name).to eq("Client")
    expect(config.current_tenant).to be_nil
  end

  it "sets values through configure block" do
    acme = Object.new

    Promotable.configure do |config|
      config.allow_stacking = false
      config.code_case_sensitive = false
      config.tenant_model_name = "Account"
      config.current_tenant_resolver = -> { acme }
    end

    expect(Promotable.configuration.allow_stacking).to be(false)
    expect(Promotable.configuration.code_case_sensitive).to be(false)
    expect(Promotable.configuration.tenant_model_name).to eq("Account")
    expect(Promotable.configuration.current_tenant).to eq(acme)
  end

  it "restores defaults with reset_configuration!" do
    Promotable.configure do |config|
      config.code_case_sensitive = false
    end

    Promotable.reset_configuration!

    expect(Promotable.configuration.code_case_sensitive).to be(true)
  end

  it "registers built-in rules and actions" do
    config = described_class.new
    config.register_defaults!

    expect(config.rule_registry.registered?(:minimum_amount)).to be(true)
    expect(config.rule_registry.registered?(:item_quantity)).to be(false)
    expect(config.rule_registry.registered?(:first_purchase)).to be(false)
    expect(config.rule_registry.registered?(:user_eligibility)).to be(false)

    expect(config.action_registry.registered?(:percentage_discount)).to be(true)
    expect(config.action_registry.registered?(:fixed_amount_discount)).to be(false)
    expect(config.action_registry.registered?(:free_shipping_discount)).to be(false)
  end
end
