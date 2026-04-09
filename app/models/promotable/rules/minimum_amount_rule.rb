module Promotable
  module Rules
    class MinimumAmountRule < Base
      store_accessor :preferences, :minimum_amount

      validates :minimum_amount, presence: true, on: :rule_validation

      def self.preference_fields
        [ { name: :minimum_amount, type: :decimal, default: 0 } ]
      end

      private

      def evaluate(promotable, _context = {})
        amount = BigDecimal(minimum_amount.to_s)
        promotable.promotable_amount >= amount
      end
    end
  end
end
