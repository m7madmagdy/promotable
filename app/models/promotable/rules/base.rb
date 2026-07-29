module Promotable
  module Rules
    class Base < ApplicationRecord
      self.table_name = "promotable_rules"

      belongs_to :promotion, class_name: "Promotable::Promotion",
                             inverse_of: :rules

      validates :type, presence: true

      class_attribute :required_context_keys, instance_writer: false, default: [].freeze

      # DSL for declaring which keys a rule expects in the evaluation context
      # (e.g. `requires_context :user` for a rule that reads context[:user]).
      # Enforced in #pre_check: raises Promotable::MissingContextError when
      # a call site omits a required key.
      def self.requires_context(*keys)
        self.required_context_keys = (required_context_keys + keys.flatten.map(&:to_sym)).uniq.freeze
      end

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

      def pre_check(_promotable, context)
        return true if self.class.required_context_keys.empty?

        missing = self.class.required_context_keys.reject { |k| context.key?(k) }
        return true if missing.empty?

        raise Promotable::MissingContextError,
              "#{self.class.name} requires context keys #{missing.inspect}; caller must pass them via Evaluator/Applicator#context."
      end

      def evaluate(_promotable, _context = {})
        raise NotImplementedError, "#{self.class.name} must implement #evaluate"
      end
    end
  end
end
