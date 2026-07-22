module Promotable
  class Configuration
    attr_accessor :allow_stacking,
                  :code_case_sensitive,
                  :current_tenant_resolver,
                  :tenant_model_name

    def initialize
      @allow_stacking = false
      @code_case_sensitive = true
      @current_tenant_resolver = nil
      @tenant_model_name = "Client"
      @rule_registry = nil
      @action_registry = nil
    end

    def current_tenant
      return nil unless current_tenant_resolver.respond_to?(:call)

      current_tenant_resolver.call
    end

    def rule_registry
      @rule_registry ||= Registry.new(Promotable::Rules::Base)
    end

    def action_registry
      @action_registry ||= Registry.new(Promotable::Actions::Base)
    end

    def register_defaults!
      rule_registry.register(:minimum_amount,    Promotable::Rules::MinimumAmountRule)

      action_registry.register(:percentage_discount,   Promotable::Actions::PercentageDiscount)
    end
  end
end
