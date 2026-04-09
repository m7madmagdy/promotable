require "test_helper"

class Promotable::ConfigurationTest < ActiveSupport::TestCase
  test "default configuration values" do
    config = Promotable::Configuration.new
    assert_equal 5, config.max_promotions_per_promotable
    assert config.allow_stacking
    assert_not config.code_case_sensitive
  end

  test "configure block sets values" do
    Promotable.configure do |config|
      config.max_promotions_per_promotable = 3
      config.allow_stacking = false
    end

    assert_equal 3, Promotable.configuration.max_promotions_per_promotable
    assert_not Promotable.configuration.allow_stacking
  end

  test "reset_configuration! restores defaults" do
    Promotable.configure do |config|
      config.max_promotions_per_promotable = 1
    end

    Promotable.reset_configuration!
    assert_equal 5, Promotable.configuration.max_promotions_per_promotable
  end

  test "register_defaults! registers built-in rules and actions" do
    config = Promotable::Configuration.new
    config.register_defaults!

    assert config.rule_registry.registered?(:minimum_amount)
    assert config.rule_registry.registered?(:item_quantity)
    assert config.rule_registry.registered?(:first_purchase)
    assert config.rule_registry.registered?(:user_eligibility)

    assert config.action_registry.registered?(:percentage_discount)
    assert config.action_registry.registered?(:fixed_amount_discount)
    assert config.action_registry.registered?(:free_shipping_discount)
  end
end
