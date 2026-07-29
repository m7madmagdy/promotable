module Promotable
  module Rules
    # Restricts the promotion to specific payment methods (e.g. wallet-only
    # cashback offers). Reads `promotable.promotable_payment_method` — the
    # host returns a string like "wallet", "card", "cash". Case-insensitive.
    class PaymentMethodRule < Base
      store_accessor :preferences, :methods

      validates :methods, presence: true, on: :rule_validation

      def self.preference_fields
        [ { name: :methods, type: :array, default: [] } ]
      end

      private

      def evaluate(promotable, _context = {})
        allowed = Array(methods).map { |m| m.to_s.downcase }
        return false if allowed.empty?

        method = Promotable::ContractResolver.call(promotable, :promotable_payment_method)
        return false if method.nil?

        allowed.include?(method.to_s.downcase)
      end
    end
  end
end
