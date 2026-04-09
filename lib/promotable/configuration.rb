module Promotable
  class Configuration
    attr_accessor :max_promotions_per_promotable,
                  :allow_stacking,
                  :code_case_sensitive

    def initialize
      @max_promotions_per_promotable = 5
      @allow_stacking = true
      @code_case_sensitive = false
      @rule_registry = nil
      @action_registry = nil
    end

    def rule_registry
      @rule_registry ||= Registry.new(Promotable::Rules::Base)
    end

    def action_registry
      @action_registry ||= Registry.new(Promotable::Actions::Base)
    end

    def register_defaults!
      rule_registry.register(:minimum_amount,    Promotable::Rules::MinimumAmountRule)
      rule_registry.register(:item_quantity,      Promotable::Rules::ItemQuantityRule)
      rule_registry.register(:first_purchase,     Promotable::Rules::FirstPurchaseRule)
      rule_registry.register(:user_eligibility,   Promotable::Rules::UserEligibilityRule)

      action_registry.register(:percentage_discount,   Promotable::Actions::PercentageDiscount)
      action_registry.register(:fixed_amount_discount,  Promotable::Actions::FixedAmountDiscount)
      action_registry.register(:free_shipping_discount, Promotable::Actions::FreeShippingDiscount)
    end
  end
end
