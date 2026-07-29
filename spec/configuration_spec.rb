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

    %i[
      minimum_amount maximum_amount country store source
      first_purchase new_user user_activity allowed_users frequency
      product_variant category minimum_quantity time_window
      payment_method birthday
    ].each do |key|
      expect(config.rule_registry.registered?(key)).to be(true), "expected rule #{key.inspect} to be registered"
    end

    %i[
      percentage_discount fixed_amount_discount capped_percentage_discount
      free_shipping tiered_discount
    ].each do |key|
      expect(config.action_registry.registered?(key)).to be(true), "expected action #{key.inspect} to be registered"
    end
  end
end
