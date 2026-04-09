module Promotable
  module Actions
    class FixedAmountDiscount < Base
      store_accessor :preferences, :amount

      validates :amount, presence: true, on: :action_validation

      def self.preference_fields
        [ { name: :amount, type: :decimal, default: 0 } ]
      end

      def compute_amount(promotable, _context = {})
        discount = BigDecimal(amount.to_s)
        promotable_amount = promotable.promotable_amount

        [ -discount, -promotable_amount ].max
      end

      def apply(promotable, context = {})
        discount = compute_amount(promotable, context)
        return if discount.zero?

        create_adjustment(promotable, discount,
          label: "#{amount} off discount")
      end
    end
  end
end
