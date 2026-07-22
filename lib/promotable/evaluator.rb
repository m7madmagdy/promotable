module Promotable
  class Evaluator
    attr_reader :promotable, :context

    def initialize(promotable, user: nil, code: nil, client: nil)
      @promotable = promotable
      @context = {
        user: user,
        code: code,
        client: client || resolve_configured_tenant
      }.compact
    end

    def eligible_promotions
      candidates = resolve_candidates
      candidates.select { |promo| promo.eligible?(promotable, context) }
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
        Promotion.available.for_client(context[:client]).to_a
      end
    end

    def promotion_for_code
      code_value = normalize_code(context[:code])

      promotion_code = PromotionCode
        .joins(:promotion)
        .where(code: code_value)
        .merge(Promotion.active)
        .merge(Promotion.for_client(context[:client]))
        .first

      promotion_code&.promotion
    end

    def normalize_code(code)
      return code if Promotable.configuration&.code_case_sensitive

      code.to_s.upcase.strip
    end

    def resolve_configured_tenant
      Promotable.configuration&.current_tenant
    end
  end
end
