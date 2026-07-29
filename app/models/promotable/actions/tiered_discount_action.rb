module Promotable
  module Actions
    # Applies the highest matching bracket from a list of (min_amount, discount)
    # tiers. Each tier is a hash with keys :min_amount and :discount; :discount
    # may be a percentage (with `:type => "percentage"`) or a fixed value
    # (default `:type => "fixed"`).
    #
    # Example — "$5 off orders of $50+, $15 off orders of $100+":
    #   tiers: [
    #     { min_amount: 50,  discount: 5,  type: "fixed" },
    #     { min_amount: 100, discount: 15, type: "fixed" }
    #   ]
    #
    # If no tier matches (i.e. the promotable falls below all min_amounts),
    # no adjustment is created.
    class TieredDiscountAction < Base
      store_accessor :preferences, :tiers

      validates :tiers, presence: true, on: :action_validation

      def self.preference_fields
        [ { name: :tiers, type: :array, default: [] } ]
      end

      def compute_amount(promotable, _context = {})
        tier = matching_tier(promotable)
        return BigDecimal("0") if tier.nil?

        base_amount = BigDecimal(promotable.promotable_amount.to_s)
        raw =
          case tier_type(tier)
          when "percentage"
            (base_amount * BigDecimal(tier_discount(tier).to_s) / 100).abs
          else
            BigDecimal(tier_discount(tier).to_s).abs
          end

        capped = [ raw, base_amount ].min
        -capped.round(4)
      end

      def apply(promotable, context = {})
        computed = compute_amount(promotable, context)
        return if computed.zero?

        create_adjustment(promotable, computed, label: adjustment_label(promotable, context))
      end

      def adjustment_label(promotable = nil, _context = {})
        tier = promotable ? matching_tier(promotable) : nil
        return self.class.display_name if tier.nil?

        case tier_type(tier)
        when "percentage" then "#{tier_discount(tier)}% off (tier ≥ #{tier_min(tier)})"
        else                   "#{tier_discount(tier)} off (tier ≥ #{tier_min(tier)})"
        end
      end

      private

      def matching_tier(promotable)
        amount = BigDecimal(promotable.promotable_amount.to_s)
        eligible = normalized_tiers.select { |t| amount >= BigDecimal(tier_min(t).to_s) }
        eligible.max_by { |t| BigDecimal(tier_min(t).to_s) }
      end

      def normalized_tiers
        Array(tiers).map { |t| t.respond_to?(:with_indifferent_access) ? t.with_indifferent_access : t }
      end

      def tier_min(tier)
        tier[:min_amount] || tier["min_amount"] || 0
      end

      def tier_discount(tier)
        tier[:discount] || tier["discount"] || 0
      end

      def tier_type(tier)
        (tier[:type] || tier["type"] || "fixed").to_s
      end
    end
  end
end
