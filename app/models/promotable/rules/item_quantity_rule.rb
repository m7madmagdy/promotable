module Promotable
  module Rules
    class ItemQuantityRule < Base
      store_accessor :preferences, :minimum_quantity

      validates :minimum_quantity, presence: true, on: :rule_validation

      def self.preference_fields
        [ { name: :minimum_quantity, type: :integer, default: 1 } ]
      end

      private

      def pre_check(promotable, _context)
        promotable.respond_to?(:promotable_items)
      end

      def evaluate(promotable, _context = {})
        qty = minimum_quantity.to_i
        promotable.promotable_items.size >= qty
      end
    end
  end
end
