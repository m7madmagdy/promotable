module Promotable
  class CodeUsage < ApplicationRecord
    belongs_to :promotion_code, class_name: "Promotable::PromotionCode",
                                inverse_of: :usages

    belongs_to :user,       polymorphic: true
    belongs_to :promotable, polymorphic: true

    validates :promotion_code_id, uniqueness: {
      scope: [ :user_type, :user_id, :promotable_type, :promotable_id ],
      message: "has already been used for this promotable"
    }

    delegate :promotion, to: :promotion_code
  end
end
