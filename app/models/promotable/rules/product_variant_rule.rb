module Promotable
  module Rules
    # Requires the cart to contain at least one item whose variant_id appears
    # in preferences[:variant_ids]. When preferences[:mode] == "exclude" the
    # rule inverts: eligible only if NONE of the listed variants are present.
    #
    # Reads `promotable.promotable_items` — an enumerable of item objects.
    # Each item must respond to `#variant_id` (or `#id` as fallback).
    class ProductVariantRule < Base
      store_accessor :preferences, :variant_ids, :mode

      validates :variant_ids, presence: true, on: :rule_validation

      def self.preference_fields
        [
          { name: :variant_ids, type: :array,  default: [] },
          { name: :mode,        type: :string, default: "include" }
        ]
      end

      private

      def evaluate(promotable, _context = {})
        target_ids = Array(variant_ids).map(&:to_i).to_set
        return false if target_ids.empty?

        items = Array(Promotable::ContractResolver.call(promotable, :promotable_items))
        item_ids = items.filter_map { |i| item_variant_id(i) }.map(&:to_i).to_set
        matched = target_ids.intersect?(item_ids)

        mode.to_s == "exclude" ? !matched : matched
      end

      def item_variant_id(item)
        return item.variant_id if item.respond_to?(:variant_id)
        return item.id         if item.respond_to?(:id)

        nil
      end
    end
  end
end
