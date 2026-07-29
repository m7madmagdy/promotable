module Promotable
  module Rules
    # Eligible on the user's birthday. Reads `user.birthday` (Date or DateTime).
    # A `window_days` preference (default 0) allows a symmetric grace period
    # around the birthday for late redemption (e.g. 3 = birthday ± 3 days).
    class BirthdayRule < Base
      requires_context :user

      store_accessor :preferences, :window_days

      def self.preference_fields
        [ { name: :window_days, type: :integer, default: 0 } ]
      end

      private

      def evaluate(_promotable, context)
        user = context[:user]
        return false if user.nil?

        birthday = Promotable::ContractResolver.call(user, :birthday)
        return false if birthday.nil?

        window = (window_days.presence || 0).to_i
        today  = Time.current.to_date

        (-window..window).any? do |offset|
          reference = today + offset
          reference.month == birthday.month && reference.day == birthday.day
        end
      end
    end
  end
end
