module Promotable
  module Rules
    # Requires the cart to contain at least one item in one of the configured
    # categories. Reads `promotable.promotable_items`; each item must respond
    # to `#category_id` or `#category_ids` (for items in multiple categories).
    class CategoryRule < Base
      store_accessor :preferences, :category_ids, :mode

      validates :category_ids, presence: true, on: :rule_validation

      def self.preference_fields
        [
          { name: :category_ids, type: :array,  default: [] },
          { name: :mode,         type: :string, default: "include" }
        ]
      end

      private

      def evaluate(promotable, _context = {})
        target_ids = Array(category_ids).map(&:to_i).to_set
        return false if target_ids.empty?

        items = Array(Promotable::ContractResolver.call(promotable, :promotable_items))
        item_categories = items.flat_map { |i| category_ids_for(i) }.compact.map(&:to_i).to_set
        matched = target_ids.intersect?(item_categories)

        mode.to_s == "exclude" ? !matched : matched
      end

      def category_ids_for(item)
        if item.respond_to?(:category_ids)
          Array(item.category_ids)
        elsif item.respond_to?(:category_id)
          [ item.category_id ]
        else
          []
        end
      end
    end
  end
end
