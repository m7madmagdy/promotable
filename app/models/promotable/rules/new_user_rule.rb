module Promotable
  module Rules
    # Eligible only when the user was created within the last N days
    # (configurable via preferences[:within_days], default 30). Reads
    # `user.created_at` — required on any ActiveRecord model.
    class NewUserRule < Base
      requires_context :user

      store_accessor :preferences, :within_days

      def self.preference_fields
        [ { name: :within_days, type: :integer, default: 30 } ]
      end

      private

      def evaluate(_promotable, context)
        user = context[:user]
        return false if user.nil? || !user.respond_to?(:created_at) || user.created_at.nil?

        cutoff = (within_days.presence || 30).to_i.days.ago
        user.created_at >= cutoff
      end
    end
  end
end
