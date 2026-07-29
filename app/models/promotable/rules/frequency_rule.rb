module Promotable
  module Rules
    # Enforces per-user redemption caps within a rolling window. Counts a
    # user's `CodeUsage` rows for this promotion inside the given period.
    #
    # preferences:
    #   max_uses (default 1) — the ceiling
    #   period   (:day | :week | :month | :ever, default :ever)
    #
    # Common patterns:
    #   * Coffee-day quota  → { max_uses: 2, period: :day }
    #   * Weekly cap        → { max_uses: 5, period: :week }
    #   * Lifetime one-shot → { max_uses: 1, period: :ever }
    class FrequencyRule < Base
      requires_context :user

      store_accessor :preferences, :max_uses, :period

      def self.preference_fields
        [
          { name: :max_uses, type: :integer, default: 1 },
          { name: :period,   type: :string,  default: "ever" }
        ]
      end

      private

      def evaluate(_promotable, context)
        user = context[:user]
        return false if user.nil?

        cap = (max_uses.presence || 1).to_i
        window = period_start
        scope = Promotable::CodeUsage
          .joins(:promotion_code)
          .where(promotable_promotion_codes: { promotion_id: promotion_id })
          .where(user_type: user.class.name, user_id: user.id)
        scope = scope.where("promotable_code_usages.created_at >= ?", window) if window

        scope.count < cap
      end

      def period_start
        case period.to_s
        when "day"   then Time.current.beginning_of_day
        when "week"  then Time.current.beginning_of_week
        when "month" then Time.current.beginning_of_month
        else nil
        end
      end
    end
  end
end
