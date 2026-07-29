module Promotable
  module Actions
    class Base < ApplicationRecord
      self.table_name = "promotable_actions"

      belongs_to :promotion, class_name: "Promotable::Promotion",
                             inverse_of: :actions

      has_many :adjustments, class_name: "Promotable::Adjustment",
                             foreign_key: :promotion_action_id,
                             dependent: :destroy

      validates :type, presence: true

      def apply(promotable, context = {})
        raise NotImplementedError, "#{self.class.name} must implement #apply"
      end

      def undo(promotable, _context = {})
        remove_adjustments(promotable)
      end

      def compute_amount(promotable, context = {})
        raise NotImplementedError, "#{self.class.name} must implement #compute_amount"
      end

      def self.preference_fields
        []
      end

      def self.display_name
        name.demodulize.underscore.humanize
      end

      # Overridable hook — subclasses can build a human-friendly label from
      # their preferences (e.g. "15% off", "$5 off", "Free shipping"). The
      # default falls back to the class display name.
      def adjustment_label(_promotable = nil, _context = {})
        self.class.display_name
      end

      private

      def create_adjustment(promotable, amount, label: nil)
        adjustments.create!(
          promotion: promotion,
          adjustable: promotable,
          amount: amount,
          label: label || adjustment_label(promotable),
          eligible: true
        )
      end

      def remove_adjustments(promotable)
        adjustments.where(
          adjustable_type: promotable.class.name,
          adjustable_id: promotable.id
        ).destroy_all
      end
    end
  end
end
