module Promotable
  module ActsAsPromoter
    extend ActiveSupport::Concern

    # No required host methods (id/class are Rails defaults).
    REQUIRED_CONTRACT_METHODS = [].freeze

    # Optional host methods unlock user-scoped built-in rules. See
    # OPTIONAL_CONTRACT_METHODS on ActsAsPromotable for the mirror on orders.
    OPTIONAL_CONTRACT_METHODS = [
      :promotable_order_count,     # FirstPurchaseRule, UserActivityRule
      :promotable_last_order_at,   # UserActivityRule
      :birthday,                   # BirthdayRule
      :promotion_group             # AllowedUsersRule
    ].freeze

    def self.required_contract_methods
      REQUIRED_CONTRACT_METHODS
    end

    def self.optional_contract_methods
      OPTIONAL_CONTRACT_METHODS
    end

    class_methods do
      def acts_as_promoter
        has_many :promotion_code_usages,
                 class_name: "Promotable::CodeUsage",
                 as: :user,
                 dependent: :destroy

        include PromoterInstanceMethods
      end
    end

    module PromoterInstanceMethods
      def promotion_usage_count(promotion)
        promotion_code_usages
          .joins(:promotion_code)
          .where(promotable_promotion_codes: { promotion_id: promotion.id })
          .count
      end

      def used_promotion?(promotion)
        promotion_usage_count(promotion) > 0
      end

      def available_promotions
        tenant = ActsAsTenant.current_tenant ||
                 Promotable.configuration&.current_tenant ||
                 (respond_to?(:client) ? client : nil)

        ActsAsTenant.with_tenant(tenant) do
          Promotable::Promotion.available.select do |promo|
            promo.within_per_user_limit?(self)
          end
        end
      end
    end
  end
end
