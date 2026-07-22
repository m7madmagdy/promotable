module Promotable
  class Promotion < ApplicationRecord
    belongs_to :client, polymorphic: true, optional: true

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
    scope :for_client, lambda { |client|
      if client.nil?
        where(client_id: nil, client_type: nil)
      else
        table = arel_table
        global = table[:client_id].eq(nil).and(table[:client_type].eq(nil))
        scoped = table[:client_id].eq(client.id).and(table[:client_type].eq(client.class.base_class.name))

        where(global.or(scoped))
      end
    }

    def eligible?(promotable, context = {})
      client = context[:client] || resolve_configured_tenant

      active? &&
        within_date_range? &&
        within_usage_limit? &&
        within_client_scope?(client) &&
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

    def within_client_scope?(candidate_client)
      return true if client_id.blank? || client_type.blank?
      return false if candidate_client.nil?

      client_type == candidate_client.class.base_class.name && client_id == candidate_client.id
    end

    def resolve_configured_tenant
      Promotable.configuration&.current_tenant
    end

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
