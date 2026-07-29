module Promotable
  module Rules
    # Explicit user allow-list. Eligible only when the user's id is in
    # preferences[:user_ids]. Also supports preferences[:user_group] where
    # the host implements `user.promotion_group` returning a symbol/string.
    class AllowedUsersRule < Base
      requires_context :user

      store_accessor :preferences, :user_ids, :user_group

      def self.preference_fields
        [
          { name: :user_ids,   type: :array,  default: [] },
          { name: :user_group, type: :string }
        ]
      end

      private

      def evaluate(_promotable, context)
        user = context[:user]
        return false if user.nil?

        matches_id?(user) || matches_group?(user)
      end

      def matches_id?(user)
        ids = Array(user_ids).map(&:to_i)
        ids.any? && ids.include?(user.id.to_i)
      end

      def matches_group?(user)
        return false if user_group.blank?

        group = Promotable::ContractResolver.call(user, :promotion_group)
        group.to_s == user_group.to_s
      end
    end
  end
end
