module Promotable
  class PromotionCode < ApplicationRecord
    belongs_to :promotion, class_name: "Promotable::Promotion",
                           inverse_of: :codes

    has_many :usages, class_name: "Promotable::CodeUsage",
                      foreign_key: :promotion_code_id,
                      dependent: :destroy,
                      inverse_of: :promotion_code

    validates :code, presence: true, uniqueness: true
    validates :usage_count, numericality: { greater_than_or_equal_to: 0 }

    before_validation :normalize_code

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
  end
end
