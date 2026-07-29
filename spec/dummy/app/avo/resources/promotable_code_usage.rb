class Avo::Resources::PromotableCodeUsage < Avo::BaseResource
  self.model_class = "Promotable::CodeUsage"
  self.title = :id
  self.description = "Redemption record: a user applied a code to a promotable object."

  def fields
    field :id, as: :id

    field :promotion_code, as: :belongs_to, readonly: true

    field :user_type,       as: :text,   readonly: true
    field :user_id,         as: :number, readonly: true

    field :promotable_type, as: :text,   readonly: true
    field :promotable_id,   as: :number, readonly: true

    field :client_id, as: :number, readonly: true, help: "Inherited from parent PromotionCode."

    field :created_at, as: :date_time, readonly: true
  end
end
