module Promotable
  module Rules
    class UserEligibilityRule < Base
      store_accessor :preferences, :eligible_group

      validates :eligible_group, presence: true, on: :rule_validation

      def self.preference_fields
        [ { name: :eligible_group, type: :string, default: nil } ]
      end

      private

      def pre_check(_promotable, context)
        context[:user].present?
      end

      def evaluate(_promotable, context = {})
        user = context[:user]
        return false unless user.respond_to?(:promotion_group)

        user.promotion_group.to_s == eligible_group.to_s
      end
    end
  end
end
