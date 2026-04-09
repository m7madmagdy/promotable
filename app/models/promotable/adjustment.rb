module Promotable
  class Adjustment < ApplicationRecord
    belongs_to :promotion,        class_name: "Promotable::Promotion",
                                  inverse_of: :adjustments

    belongs_to :promotion_action, class_name: "Promotable::Actions::Base"
    belongs_to :adjustable,       polymorphic: true

    validates :amount, presence: true, numericality: true
    validates :label,  presence: true

    scope :eligible,   -> { where(eligible: true) }
    scope :ineligible, -> { where(eligible: false) }
    scope :credits,    -> { where("amount < 0") }
    scope :debits,     -> { where("amount > 0") }

    scope :for_promotable, ->(promotable) {
      where(adjustable_type: promotable.class.name, adjustable_id: promotable.id)
    }

    def credit?
      amount.negative?
    end

    def debit?
      amount.positive?
    end
  end
end
