module Promotable
  module Rules
    # Requires the promotable's source (e.g. "web", "ios", "kiosk") to appear
    # in the configured allow-list. Case-insensitive. Reads
    # `promotable.promotable_source`.
    class SourceRule < Base
      store_accessor :preferences, :sources

      validates :sources, presence: true, on: :rule_validation

      def self.preference_fields
        [ { name: :sources, type: :array, default: [] } ]
      end

      private

      def evaluate(promotable, _context = {})
        allowed = Array(sources).map { |s| s.to_s.downcase }
        return false if allowed.empty?

        source = Promotable::ContractResolver.call(promotable, :promotable_source)
        return false if source.nil?

        allowed.include?(source.to_s.downcase)
      end
    end
  end
end
