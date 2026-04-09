module Promotable
  module ActsAsPromoter
    extend ActiveSupport::Concern

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
        Promotable::Promotion.available.select do |promo|
          promo.within_per_user_limit?(self)
        end
      end
    end
  end
end
