module Promotable
  class Error < StandardError; end

  class InvalidCodeError < Error; end
  class IneligibleError < Error; end
  class UsageLimitExceededError < Error; end
  class PromotionExpiredError < Error; end
  class PromotionInactiveError < Error; end
  class StackingNotAllowedError < Error; end
  class MaxPromotionsExceededError < Error; end
  class PromotableInterfaceError < Error; end
end
