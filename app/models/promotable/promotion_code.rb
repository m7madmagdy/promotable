module Promotable
  class PromotionCode < ApplicationRecord
    include Promotable::TenantScoped

    belongs_to :promotion, class_name: "Promotable::Promotion",
                           inverse_of: :codes

    has_many :usages, class_name: "Promotable::CodeUsage",
                      foreign_key: :promotion_code_id,
                      dependent: :destroy,
                      inverse_of: :promotion_code

    # Codes are unique within a tenant so different clients can safely reuse
    # the same coupon string (e.g. two clients both running WELCOME10).
    validates :code, presence: true, uniqueness: { scope: :client_id }
    validates :usage_count, numericality: { greater_than_or_equal_to: 0 }

    before_validation :normalize_code
    before_validation :inherit_client_from_promotion
    validate :client_matches_promotion

    scope :available, -> { where("usage_limit IS NULL OR usage_count < usage_limit") }

    def redeemable?
      promotion.active? &&
        promotion.within_date_range? &&
        within_usage_limit?
    end

    def within_usage_limit?
      usage_limit.blank? || usage_count < usage_limit
    end

    def increment_usage!
      increment!(:usage_count)
    end

    private

    def normalize_code
      return if Promotable.configuration&.code_case_sensitive

      self.code = code&.upcase&.strip
    end

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
