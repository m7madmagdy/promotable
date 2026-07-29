module Promotable
  class Configuration
    attr_accessor :allow_stacking,
                  :code_case_sensitive,
                  :current_tenant_resolver,
                  :tenant_model_name,
                  :require_tenant,
                  :on_missing_contract_method
    attr_writer   :logger

    def initialize
      @allow_stacking = false
      @code_case_sensitive = true
      @current_tenant_resolver = nil
      @tenant_model_name = "Client"
      @require_tenant = false
      @on_missing_contract_method = :log
      @logger = nil
      @rule_registry = nil
      @action_registry = nil
    end

    # Returns the current tenant. Precedence:
    #   1. ActsAsTenant.current_tenant (if set within a `with_tenant` block)
    #   2. current_tenant_resolver.call (if configured)
    #   3. nil (global/unscoped)
    def current_tenant
      return ActsAsTenant.current_tenant if defined?(ActsAsTenant) && ActsAsTenant.current_tenant
      return nil unless current_tenant_resolver.respond_to?(:call)

      current_tenant_resolver.call
    end

    # Falls back to Rails.logger at read time so setting Configuration in an
    # initializer doesn't need to reference the (possibly not-yet-loaded) logger.
    def logger
      @logger || (defined?(Rails) && Rails.respond_to?(:logger) ? Rails.logger : nil)
    end

    def rule_registry
      @rule_registry ||= Registry.new(Promotable::Rules::Base)
    end

    def action_registry
      @action_registry ||= Registry.new(Promotable::Actions::Base)
    end

    def register_defaults!
      rule_registry.register(:minimum_amount,   Promotable::Rules::MinimumAmountRule)
      rule_registry.register(:maximum_amount,   Promotable::Rules::MaximumAmountRule)
      rule_registry.register(:country,          Promotable::Rules::CountryRule)
      rule_registry.register(:store,            Promotable::Rules::StoreRule)
      rule_registry.register(:source,           Promotable::Rules::SourceRule)
      rule_registry.register(:first_purchase,   Promotable::Rules::FirstPurchaseRule)
      rule_registry.register(:new_user,         Promotable::Rules::NewUserRule)
      rule_registry.register(:user_activity,    Promotable::Rules::UserActivityRule)
      rule_registry.register(:allowed_users,    Promotable::Rules::AllowedUsersRule)
      rule_registry.register(:frequency,        Promotable::Rules::FrequencyRule)
      rule_registry.register(:product_variant,  Promotable::Rules::ProductVariantRule)
      rule_registry.register(:category,         Promotable::Rules::CategoryRule)
      rule_registry.register(:minimum_quantity, Promotable::Rules::MinimumQuantityRule)
      rule_registry.register(:time_window,      Promotable::Rules::TimeWindowRule)
      rule_registry.register(:payment_method,   Promotable::Rules::PaymentMethodRule)
      rule_registry.register(:birthday,         Promotable::Rules::BirthdayRule)

      action_registry.register(:percentage_discount,        Promotable::Actions::PercentageDiscount)
      action_registry.register(:fixed_amount_discount,      Promotable::Actions::FixedAmountDiscount)
      action_registry.register(:capped_percentage_discount, Promotable::Actions::CappedPercentageDiscount)
      action_registry.register(:free_shipping,              Promotable::Actions::FreeShippingAction)
      action_registry.register(:tiered_discount,            Promotable::Actions::TieredDiscountAction)
    end
  end
end
