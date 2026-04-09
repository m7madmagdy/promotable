module Promotable
  module Actions
    class FreeShippingDiscount < Base
      def self.preference_fields
        []
      end

      def compute_amount(promotable, _context = {})
        return BigDecimal("0") unless promotable.respond_to?(:promotable_shipping_cost)

        -BigDecimal(promotable.promotable_shipping_cost.to_s)
      end

      def apply(promotable, context = {})
        discount = compute_amount(promotable, context)
        return if discount.zero?

        create_adjustment(promotable, discount,
          label: "Free shipping")
      end
    end
  end
end
