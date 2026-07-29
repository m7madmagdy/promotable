module Promotable
  module Rules
    # Eligible only when the user has zero prior promotable orders. Uses the
    # host-provided `user.promotable_order_count` (defaults to 0 via
    # ContractResolver when the host doesn't implement it).
    class FirstPurchaseRule < Base
      requires_context :user

      def self.preference_fields
        []
      end

      private

      def evaluate(_promotable, context)
        user = context[:user]
        return false if user.nil?

        count = Promotable::ContractResolver.call(user, :promotable_order_count)
        count.to_i.zero?
      end
    end
  end
end
