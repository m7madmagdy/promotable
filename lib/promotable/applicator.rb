module Promotable
  class Applicator
    attr_reader :promotable, :user, :client

    def initialize(promotable, user: nil, client: nil)
      @promotable = promotable
      @user = user
      @client = client || resolve_configured_tenant
    end

    def apply(promotions)
      with_tenant_scope do
        promotions = Array(promotions)

        sorted = promotions.sort_by(&:priority)
        applied = existing_promotion_ids

        sorted.each do |promo|
          next if applied.include?(promo.id)
          next unless can_stack?(promo, applied)

          apply_promotion(promo)
          applied << promo.id
        end
      end
    end

    def apply_single(promotion)
      raise IneligibleError, "Promotion is not eligible" unless promotion.eligible?(promotable, user: user, client: client)

      with_tenant_scope { apply_promotion(promotion) }
    end

    def remove(promotion)
      with_tenant_scope do
        promotion.actions.each { |action| action.undo(promotable) }
        sync_discounted_total!
      end
    end

    def remove_all
      with_tenant_scope do
        Adjustment
          .where(adjustable_type: promotable.class.name, adjustable_id: promotable.id)
          .destroy_all

        sync_discounted_total!
      end
    end

    private

    def apply_promotion(promotion)
      ActiveRecord::Base.transaction do
        promotion.actions.each do |action|
          action.apply(promotable, user: user)
        end

        sync_discounted_total!
        promotion.increment_usage!
      end
    end

    def can_stack?(promotion, applied_ids)
      return true if applied_ids.empty?

      config = Promotable.configuration
      return true if config&.allow_stacking && promotion.stackable?

      applied_ids.empty?
    end

    def current_discount_total
      BigDecimal(
        Adjustment
          .where(adjustable_type: promotable.class.name, adjustable_id: promotable.id)
          .where(eligible: true)
          .sum(:amount)
          .to_s
      )
    end

    def sync_discounted_total!
      target_column = discounted_total_column
      return if target_column.nil?

      base_total = BigDecimal(promotable.total_amount.to_s)
      discounted_total = (base_total + current_discount_total).round(4)
      current_value = BigDecimal(promotable.public_send(target_column).to_s)
      return if current_value == discounted_total

      promotable.update!(target_column => discounted_total)
    end

    def discounted_total_column
      if promotable.respond_to?(:total_after_discounts) && promotable.respond_to?(:total_after_discounts=)
        :total_after_discounts
      elsif promotable.respond_to?(:total_amount) && promotable.respond_to?(:total_amount=)
        :total_amount
      end
    end

    def existing_promotion_ids
      Adjustment
        .where(adjustable_type: promotable.class.name, adjustable_id: promotable.id)
        .where(eligible: true)
        .pluck(:promotion_id)
        .uniq
    end

    def resolve_configured_tenant
      Promotable.configuration&.current_tenant
    end

    def with_tenant_scope(&block)
      ActsAsTenant.with_tenant(@client, &block)
    end
  end
end
