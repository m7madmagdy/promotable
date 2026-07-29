module Promotable
  module Actions
    # Flat monetary discount. The absolute amount configured is capped at the
    # promotable's amount so we never issue a negative-total order.
    #
    # preferences:
    #   amount — positive number (dollars, cents, etc. — units match your host's promotable_amount)
    class FixedAmountDiscount < Base
      store_accessor :preferences, :amount

      validates :amount, presence: true, on: :action_validation

      def self.preference_fields
        [ { name: :amount, type: :decimal, default: 0 } ]
      end

      def compute_amount(promotable, _context = {})
        raw    = BigDecimal(amount.to_s).abs
        capped = [ raw, BigDecimal(promotable.promotable_amount.to_s) ].min
        -capped.round(4)
      end

      def apply(promotable, context = {})
        computed = compute_amount(promotable, context)
        return if computed.zero?

        create_adjustment(promotable, computed, label: adjustment_label(promotable, context))
      end

      def adjustment_label(_promotable = nil, _context = {})
        "#{BigDecimal(amount.to_s).abs.to_s('F')} off"
      end
    end
  end
end
