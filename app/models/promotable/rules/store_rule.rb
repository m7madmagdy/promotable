module Promotable
  module Rules
    # Requires the promotable's store id to appear in the configured allow-list.
    # Reads `promotable.promotable_store_id` (or falls back to `store_id`).
    class StoreRule < Base
      store_accessor :preferences, :store_ids

      validates :store_ids, presence: true, on: :rule_validation

      def self.preference_fields
        [ { name: :store_ids, type: :array, default: [] } ]
      end

      private

      def evaluate(promotable, _context = {})
        allowed = Array(store_ids).map(&:to_i)
        return false if allowed.empty?

        store_id = Promotable::ContractResolver.call(promotable, :promotable_store_id)
        return false if store_id.nil?

        allowed.include?(store_id.to_i)
      end
    end
  end
end
