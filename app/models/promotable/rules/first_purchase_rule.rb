module Promotable
  module Rules
    class FirstPurchaseRule < Base
      def self.preference_fields
        []
      end

      private

      def pre_check(_promotable, context)
        context[:user].present?
      end

      def evaluate(_promotable, context = {})
        user = context[:user]
        return false unless user.respond_to?(:promotion_code_usages)

        user.promotion_code_usages.empty?
      end
    end
  end
end
