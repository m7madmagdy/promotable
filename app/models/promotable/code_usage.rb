module Promotable
  class CodeUsage < ApplicationRecord
    include Promotable::TenantScoped

    belongs_to :promotion_code, class_name: "Promotable::PromotionCode",
                                inverse_of: :usages

    belongs_to :user,       polymorphic: true
    belongs_to :promotable, polymorphic: true

    validates :promotion_code_id, uniqueness: {
      scope: [ :user_type, :user_id, :promotable_type, :promotable_id ],
      message: "has already been used for this promotable"
    }

    before_validation :inherit_client_from_promotion_code
    validate :client_matches_promotion_code

    delegate :promotion, to: :promotion_code

    private

    def inherit_client_from_promotion_code
      return if promotion_code.nil?

      self.client_id = promotion_code.client_id
    end

    def client_matches_promotion_code
      return if promotion_code.nil?
      return if client_id == promotion_code.client_id

      errors.add(:client_id, "must match the promotion code's client")
    end
  end
end
