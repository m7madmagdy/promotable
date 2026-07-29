module Promotable
  class CodeRedeemer
    attr_reader :code_string, :promotable, :user, :client

    def initialize(code_string, promotable:, user: nil, client: nil)
      @code_string = code_string
      @promotable  = promotable
      @user        = user
      @client      = client || resolve_configured_tenant
    end

    def redeem
      ActsAsTenant.with_tenant(client) do
        promotion_code = find_code!
        promotion = promotion_code.promotion

        validate_promotion!(promotion)
        validate_code!(promotion_code)
        validate_user_limit!(promotion) if user

        ActiveRecord::Base.transaction do
          applicator = Applicator.new(promotable, user: user, client: client)
          applicator.apply_single(promotion)

          promotion_code.increment_usage!
          record_usage(promotion_code)
        end

        promotion
      end
    end

    private

    # Runs inside the caller's with_tenant block, so acts_as_tenant's
    # default_scope filters PromotionCode to the current tenant automatically.
    # A code belonging to a different tenant simply won't be found.
    def find_code!
      code = PromotionCode.find_by(code: normalize_code(code_string))
      raise InvalidCodeError, "Promotion code '#{code_string}' not found" if code.nil?

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

    def resolve_configured_tenant
      Promotable.configuration&.current_tenant
    end
  end
end
