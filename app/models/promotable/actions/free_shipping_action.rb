module Promotable
  module Actions
    # Waives shipping. Reads `promotable.promotable_shipping_cost` and issues
    # a negative adjustment equal to that value. If the host doesn't have a
    # separate shipping cost, ContractResolver returns nil and no adjustment
    # is created (silent no-op with a logged warning).
    class FreeShippingAction < Base
      def self.preference_fields
        []
      end

      def compute_amount(promotable, _context = {})
        shipping = Promotable::ContractResolver.call(promotable, :promotable_shipping_cost)
        return BigDecimal("0") if shipping.nil?

        -BigDecimal(shipping.to_s).abs.round(4)
      end

      def apply(promotable, context = {})
        computed = compute_amount(promotable, context)
        return if computed.zero?

        create_adjustment(promotable, computed, label: adjustment_label(promotable, context))
      end

      def adjustment_label(_promotable = nil, _context = {})
        "Free shipping"
      end
    end
  end
end
