module Promotable
  class Promotion < ApplicationRecord
    include Promotable::TenantScoped

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

    # Cross-tenant lookup helper. Prefer `ActsAsTenant.with_tenant(client) { ... }`
    # in application code; this scope exists mainly for admin tooling and
    # tests that need to inspect visibility from a given tenant's perspective
    # without switching Current.tenant.
    scope :for_client, lambda { |client|
      base = unscoped
      if client.nil?
        base.where(client_id: nil)
      else
        base.where(client_id: [ nil, client.id ])
      end
    }

    # Keep tenant-scoped children (codes, usages, adjustments) in sync when a
    # promotion is (re)assigned to a client. Required because acts_as_tenant
    # allows a nil → value transition on the parent, but children were
    # snapshotted at creation time.
    after_save :propagate_client_id_to_children, if: :saved_change_to_client_id?

    def eligible?(promotable, context = {})
      candidate_client = context[:client] || Promotable.configuration&.current_tenant || promotable.try(:client)

      active? &&
        within_date_range? &&
        within_usage_limit? &&
        within_client_scope?(candidate_client) &&
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

    # Global promotions (client_id: nil) are visible to every tenant, so
    # they always pass the scope check. A tenant-scoped promotion only
    # matches the exact client passed in.
    def within_client_scope?(candidate_client)
      return true if client_id.nil?
      return false if candidate_client.nil?

      client_id == candidate_client.id
    end

    def propagate_client_id_to_children
      new_client_id = client_id
      ActsAsTenant.without_tenant do
        code_ids = Promotable::PromotionCode.where(promotion_id: id).pluck(:id)
        Promotable::PromotionCode.where(id: code_ids).update_all(client_id: new_client_id)
        Promotable::CodeUsage.where(promotion_code_id: code_ids).update_all(client_id: new_client_id)
        Promotable::Adjustment.where(promotion_id: id).update_all(client_id: new_client_id)
      end
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
