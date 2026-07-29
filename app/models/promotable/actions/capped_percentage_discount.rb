module Promotable
  module Actions
    # Percentage discount with a hard cap. Common for "20% off, max $30".
    #
    # preferences:
    #   percentage — 0..100 (percent of promotable_amount to discount)
    #   max_amount — optional cap; nil/blank means uncapped
    class CappedPercentageDiscount < Base
      store_accessor :preferences, :percentage, :max_amount

      validates :percentage, presence: true, on: :action_validation

      def self.preference_fields
        [
          { name: :percentage, type: :decimal, default: 0 },
          { name: :max_amount, type: :decimal }
        ]
      end

      def compute_amount(promotable, _context = {})
        pct = BigDecimal(percentage.to_s)
        raw = (BigDecimal(promotable.promotable_amount.to_s) * pct / 100)

        capped = if max_amount.present?
          [ raw.abs, BigDecimal(max_amount.to_s).abs ].min
        else
          raw.abs
        end

        -capped.round(4)
      end

      def apply(promotable, context = {})
        computed = compute_amount(promotable, context)
        return if computed.zero?

        create_adjustment(promotable, computed, label: adjustment_label(promotable, context))
      end

      def adjustment_label(_promotable = nil, _context = {})
        cap = max_amount.present? ? " (max #{BigDecimal(max_amount.to_s).abs.to_s('F')})" : ""
        "#{percentage}% off#{cap}"
      end
    end
  end
end
