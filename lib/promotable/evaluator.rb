module Promotable
  class Evaluator
    attr_reader :promotable, :context

    def initialize(promotable, user: nil, code: nil, client: nil)
      @promotable = promotable
      @client = client || resolve_configured_tenant
      @context = { user: user, code: code, client: @client }.compact
    end

    def eligible_promotions
      with_tenant_scope do
        candidates = resolve_candidates
        candidates.select { |promo| promo.eligible?(promotable, context) }
      end
    end

    def best_promotion
      eligible = eligible_promotions
      return nil if eligible.empty?

      eligible.min_by(&:priority)
    end

    private

    def resolve_candidates
      if context[:code]
        Array(promotion_for_code)
      else
        Promotion.available.to_a
      end
    end

    def promotion_for_code
      PromotionCode
        .joins(:promotion)
        .where(code: normalize_code(context[:code]))
        .merge(Promotion.active)
        .first
        &.promotion
    end

    def normalize_code(code)
      return code if Promotable.configuration&.code_case_sensitive

      code.to_s.upcase.strip
    end

    def resolve_configured_tenant
      Promotable.configuration&.current_tenant
    end

    def with_tenant_scope(&block)
      ActsAsTenant.with_tenant(@client, &block)
    end
  end
end
