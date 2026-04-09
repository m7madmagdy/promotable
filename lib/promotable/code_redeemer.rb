module Promotable
  class CodeRedeemer
    attr_reader :code_string, :promotable, :user

    def initialize(code_string, promotable:, user: nil)
      @code_string = code_string
      @promotable  = promotable
      @user        = user
    end

    def redeem
      promotion_code = find_code!
      promotion = promotion_code.promotion

      validate_promotion!(promotion)
      validate_code!(promotion_code)
      validate_user_limit!(promotion) if user

      ActiveRecord::Base.transaction do
        applicator = Applicator.new(promotable, user: user)
        applicator.apply_single(promotion)

        promotion_code.increment_usage!
        record_usage(promotion_code)
      end

      promotion
    end

    private

    def find_code!
      normalized = normalize_code(code_string)
      code = PromotionCode.find_by(code: normalized)

      raise InvalidCodeError, "Promotion code '#{code_string}' not found" unless code

      code
    end

    def validate_promotion!(promotion)
      raise PromotionInactiveError, "Promotion '#{promotion.name}' is not active" unless promotion.active?
      raise PromotionExpiredError, "Promotion '#{promotion.name}' has expired" if promotion.expired?
      raise PromotionExpiredError, "Promotion '#{promotion.name}' has not started yet" unless promotion.started?
      raise UsageLimitExceededError, "Promotion '#{promotion.name}' usage limit reached" unless promotion.within_usage_limit?
    end

    def validate_code!(promotion_code)
      raise UsageLimitExceededError, "Code '#{code_string}' usage limit reached" unless promotion_code.within_usage_limit?
    end

    def validate_user_limit!(promotion)
      return if promotion.within_per_user_limit?(user)

      raise UsageLimitExceededError, "Per-user limit reached for promotion '#{promotion.name}'"
    end

    def record_usage(promotion_code)
      return unless user

      CodeUsage.create!(
        promotion_code: promotion_code,
        user: user,
        promotable: promotable
      )
    end

    def normalize_code(code)
      return code if Promotable.configuration&.code_case_sensitive

      code.to_s.upcase.strip
    end
  end
end
