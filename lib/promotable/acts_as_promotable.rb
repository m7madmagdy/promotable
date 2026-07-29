module Promotable
  module ActsAsPromotable
    extend ActiveSupport::Concern

    # Methods the host promotable model MUST implement. Missing methods here
    # raise Promotable::PromotableInterfaceError from the base implementation.
    REQUIRED_CONTRACT_METHODS = [ :promotable_amount ].freeze

    # Methods host apps MAY implement to unlock additional built-in rules and
    # actions. When missing, Promotable::ContractResolver returns nil and
    # rules that depend on them evaluate to ineligible. See
    # `Promotable.configuration.on_missing_contract_method` for warn/raise/skip.
    OPTIONAL_CONTRACT_METHODS = [
      :promotable_items,
      :promotable_item_count,
      :promotable_shipping_cost,
      :promotable_country,
      :promotable_store_id,
      :promotable_source,
      :promotable_payment_method
    ].freeze

    def self.required_contract_methods
      REQUIRED_CONTRACT_METHODS
    end

    def self.optional_contract_methods
      OPTIONAL_CONTRACT_METHODS
    end

    class_methods do
      def acts_as_promotable
        has_many :promotable_adjustments,
                 class_name: "Promotable::Adjustment",
                 as: :adjustable,
                 dependent: :destroy

        has_many :promotable_code_usages,
                 class_name: "Promotable::CodeUsage",
                 as: :promotable,
                 dependent: :destroy

        include PromotableInstanceMethods

        validate :validate_promotable_interface, on: :create, if: :class.respond_to?(:promotable_interface_validation?) ? :promotable_interface_validation? : -> { false }
      end
    end

    module PromotableInstanceMethods
      def apply_promotion_code(code, user: nil)
        Promotable::CodeRedeemer.new(code, promotable: self, user: user).redeem
      end

      def apply_best_promotions(user: nil)
        evaluator  = Promotable::Evaluator.new(self, user: user)
        applicator = Promotable::Applicator.new(self, user: user)
        applicator.apply(evaluator.eligible_promotions)
      end

      def remove_all_promotions
        Promotable::Applicator.new(self).remove_all
      end

      def recalculate_promotions(user: nil)
        remove_all_promotions
        apply_best_promotions(user: user)
      end

      def promotion_total_discount
        promotable_adjustments.eligible.sum(:amount)
      end

      def promotable_amount
        raise Promotable::PromotableInterfaceError,
          "#{self.class.name} must implement #promotable_amount returning a BigDecimal"
      end

      def active_promotions
        promotable_adjustments
          .eligible
          .includes(:promotion)
          .map(&:promotion)
          .uniq
      end
    end
  end
end
