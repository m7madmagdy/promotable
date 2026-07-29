module Promotable
  module Rules
    # Requires the cart's total item count to meet a minimum. Reads
    # `promotable.promotable_item_count` if implemented, else counts
    # `promotable.promotable_items.size`.
    class MinimumQuantityRule < Base
      store_accessor :preferences, :minimum_quantity

      validates :minimum_quantity, presence: true, on: :rule_validation

      def self.preference_fields
        [ { name: :minimum_quantity, type: :integer, default: 1 } ]
      end

      private

      def evaluate(promotable, _context = {})
        min = (minimum_quantity.presence || 1).to_i
        count = if promotable.respond_to?(:promotable_item_count)
          promotable.promotable_item_count.to_i
        else
          Array(Promotable::ContractResolver.call(promotable, :promotable_items)).sum { |i| item_quantity(i) }
        end

        count >= min
      end

      def item_quantity(item)
        return item.quantity.to_i if item.respond_to?(:quantity)

        1
      end
    end
  end
end
