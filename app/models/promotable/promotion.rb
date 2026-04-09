module Promotable
  class Promotion < ApplicationRecord
    has_many :rules,       class_name: "Promotable::Rules::Base",
                           foreign_key: :promotion_id,
                           dependent: :destroy,
                           inverse_of: :promotion

    has_many :actions,     class_name: "Promotable::Actions::Base",
                           foreign_key: :promotion_id,
                           dependent: :destroy,
                           inverse_of: :promotion

    has_many :codes,       class_name: "Promotable::PromotionCode",
                           foreign_key: :promotion_id,
                           dependent: :destroy,
                           inverse_of: :promotion

    has_many :adjustments, class_name: "Promotable::Adjustment",
                           foreign_key: :promotion_id,
                           dependent: :destroy,
                           inverse_of: :promotion

    validates :name, presence: true
    validates :usage_count, numericality: { greater_than_or_equal_to: 0 }
    validates :priority,    numericality: { only_integer: true }
    validate  :validate_date_range

    scope :active,      -> { where(active: true) }
    scope :inactive,    -> { where(active: false) }
    scope :current,     -> { where("starts_at IS NULL OR starts_at <= ?", Time.current)
                             .where("expires_at IS NULL OR expires_at >= ?", Time.current) }
    scope :by_priority, -> { order(priority: :asc) }
    scope :stackable,   -> { where(stackable: true) }
    scope :available,   -> { active.current.by_priority }

    def eligible?(promotable, context = {})
      active? &&
        within_date_range? &&
        within_usage_limit? &&
        within_per_user_limit?(context[:user]) &&
        rules_satisfied?(promotable, context)
    end

    def expired?
      expires_at.present? && expires_at < Time.current
    end

    def started?
      starts_at.blank? || starts_at <= Time.current
    end

    def within_date_range?
      started? && !expired?
    end

    def within_usage_limit?
      usage_limit.blank? || usage_count < usage_limit
    end

    def within_per_user_limit?(user)
      return true if per_user_limit.blank? || user.nil?

      user_usage = CodeUsage.where(
        promotion_code: codes,
        user_type: user.class.name,
        user_id: user.id
      ).count

      user_usage < per_user_limit
    end

    def increment_usage!
      increment!(:usage_count)
    end

    private

    def rules_satisfied?(promotable, context)
      rules.all? { |rule| rule.eligible?(promotable, context) }
    end

    def validate_date_range
      return if starts_at.blank? || expires_at.blank?

      if expires_at <= starts_at
        errors.add(:expires_at, "must be after starts_at")
      end
    end
  end
end
