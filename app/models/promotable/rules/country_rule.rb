module Promotable
  module Rules
    # Requires the promotable's country to appear in the configured list.
    # Reads `promotable.promotable_country` (via ContractResolver) — the host
    # returns a country code string (e.g. "US"). Comparison is case-insensitive.
    class CountryRule < Base
      store_accessor :preferences, :countries

      validates :countries, presence: true, on: :rule_validation

      def self.preference_fields
        [ { name: :countries, type: :array, default: [] } ]
      end

      private

      def evaluate(promotable, _context = {})
        allowed = Array(countries).map { |c| c.to_s.upcase }
        return false if allowed.empty?

        country = Promotable::ContractResolver.call(promotable, :promotable_country)
        return false if country.nil?

        allowed.include?(country.to_s.upcase)
      end
    end
  end
end
