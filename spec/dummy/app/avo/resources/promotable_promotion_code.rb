class Avo::Resources::PromotablePromotionCode < Avo::BaseResource
  self.model_class = "Promotable::PromotionCode"
  self.title = :code
  self.description = "A redeemable code that grants access to a Promotion."

  def fields
    field :id, as: :id

    field :promotion, as: :belongs_to, required: true
    field :code,      as: :text,        required: true

    field :usage_limit, as: :number, help: "Total redemptions allowed. Blank = unlimited."
    field :usage_count, as: :number, readonly: true, hide_on: %i[new edit]

    field :client_id, as: :number,
          readonly: true,
          hide_on: %i[new edit],
          help: "Inherited from parent Promotion."

    field :usages, as: :has_many
  end
end
