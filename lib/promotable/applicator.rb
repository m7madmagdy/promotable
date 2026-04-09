module Promotable
  class Applicator
    attr_reader :promotable, :user

    def initialize(promotable, user: nil)
      @promotable = promotable
      @user = user
    end

    def apply(promotions)
      promotions = Array(promotions)
      config = Promotable.configuration

      sorted = promotions.sort_by(&:priority)
      applied = existing_promotion_ids

      sorted.each do |promo|
        break if config && applied.size >= config.max_promotions_per_promotable

        next if applied.include?(promo.id)
        next unless can_stack?(promo, applied)

        apply_promotion(promo)
        applied << promo.id
      end
    end

    def apply_single(promotion)
      raise IneligibleError, "Promotion is not eligible" unless promotion.eligible?(promotable, user: user)

      apply_promotion(promotion)
    end

    def remove(promotion)
      promotion.actions.each { |action| action.undo(promotable) }
    end

    def remove_all
      Adjustment
        .where(adjustable_type: promotable.class.name, adjustable_id: promotable.id)
        .destroy_all
    end

    private

    def apply_promotion(promotion)
      ActiveRecord::Base.transaction do
        promotion.actions.each do |action|
          action.apply(promotable, user: user)
        end
        promotion.increment_usage!
      end
    end

    def can_stack?(promotion, applied_ids)
      return true if applied_ids.empty?

      config = Promotable.configuration
      return true if config&.allow_stacking && promotion.stackable?

      applied_ids.empty?
    end

    def existing_promotion_ids
      Adjustment
        .where(adjustable_type: promotable.class.name, adjustable_id: promotable.id)
        .where(eligible: true)
        .pluck(:promotion_id)
        .uniq
    end
  end
end
