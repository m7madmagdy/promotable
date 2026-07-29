module Promotable
  module Rules
    # Requires the user to be within a configured order-count range and/or
    # to have placed their most recent order no more than `max_days_since_last`
    # days ago. Both bounds are optional; when both are nil the rule always
    # passes (given a user is provided).
    #
    # Reads:
    #   user.promotable_order_count       (via ContractResolver, defaults to nil)
    #   user.promotable_last_order_at     (via ContractResolver, defaults to nil)
    class UserActivityRule < Base
      requires_context :user

      store_accessor :preferences, :min_orders, :max_orders, :max_days_since_last

      def self.preference_fields
        [
          { name: :min_orders,           type: :integer },
          { name: :max_orders,           type: :integer },
          { name: :max_days_since_last,  type: :integer }
        ]
      end

      private

      def evaluate(_promotable, context)
        user = context[:user]
        return false if user.nil?

        count      = Promotable::ContractResolver.call(user, :promotable_order_count)
        last_order = Promotable::ContractResolver.call(user, :promotable_last_order_at)

        within_order_count?(count) && within_recency?(last_order)
      end

      def within_order_count?(count)
        return true if min_orders.blank? && max_orders.blank?

        value = count.to_i
        (min_orders.blank? || value >= min_orders.to_i) &&
          (max_orders.blank? || value <= max_orders.to_i)
      end

      def within_recency?(last_order)
        return true if max_days_since_last.blank?
        return false if last_order.nil?

        last_order >= max_days_since_last.to_i.days.ago
      end
    end
  end
end
