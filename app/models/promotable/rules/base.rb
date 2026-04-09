module Promotable
  module Rules
    class Base < ApplicationRecord
      self.table_name = "promotable_rules"

      belongs_to :promotion, class_name: "Promotable::Promotion",
                             inverse_of: :rules

      validates :type, presence: true

      def eligible?(promotable, context = {})
        return false unless pre_check(promotable, context)

        evaluate(promotable, context)
      end

      def self.preference_fields
        []
      end

      def self.display_name
        name.demodulize.underscore.humanize
      end

      private

      def pre_check(_promotable, _context)
        true
      end

      def evaluate(_promotable, _context = {})
        raise NotImplementedError, "#{self.class.name} must implement #evaluate"
      end
    end
  end
end
