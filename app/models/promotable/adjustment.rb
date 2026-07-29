module Promotable
  class Adjustment < ApplicationRecord
    include Promotable::TenantScoped

    belongs_to :promotion,        class_name: "Promotable::Promotion",
                                  inverse_of: :adjustments

    belongs_to :promotion_action, class_name: "Promotable::Actions::Base"
    belongs_to :adjustable,       polymorphic: true

    validates :amount, presence: true, numericality: true
    validates :label,  presence: true

    before_validation :inherit_client_from_promotion
    validate :client_matches_promotion

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

    private

    def inherit_client_from_promotion
      return if promotion.nil?

      self.client_id = promotion.client_id
    end

    def client_matches_promotion
      return if promotion.nil?
      return if client_id == promotion.client_id

      errors.add(:client_id, "must match the promotion's client")
    end
  end
end
