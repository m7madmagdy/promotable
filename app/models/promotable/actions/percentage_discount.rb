module Promotable
  module Actions
    class PercentageDiscount < Base
      store_accessor :preferences, :percentage

      validates :percentage, presence: true, on: :action_validation

      def self.preference_fields
        [ { name: :percentage, type: :decimal, default: 0 } ]
      end

      def compute_amount(promotable, _context = {})
        pct = BigDecimal(percentage.to_s)
        -(promotable.promotable_amount * pct / 100).round(4)
      end

      def apply(promotable, context = {})
        amount = compute_amount(promotable, context)
        return if amount.zero?

        create_adjustment(promotable, amount,
          label: "#{percentage}% discount")
      end
    end
  end
end
