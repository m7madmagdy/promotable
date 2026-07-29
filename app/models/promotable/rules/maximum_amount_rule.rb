module Promotable
  module Rules
    # Ineligible when the promotable's amount exceeds a ceiling. Useful for
    # promotions that only apply to small carts (e.g. "5% off orders under $50").
    class MaximumAmountRule < Base
      store_accessor :preferences, :maximum_amount

      validates :maximum_amount, presence: true, on: :rule_validation

      def self.preference_fields
        [ { name: :maximum_amount, type: :decimal, default: 0 } ]
      end

      private

      def evaluate(promotable, _context = {})
        amount = BigDecimal(maximum_amount.to_s)
        promotable.promotable_amount <= amount
      end
    end
  end
end
