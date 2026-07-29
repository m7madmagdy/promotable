class Avo::Resources::PromotableAdjustment < Avo::BaseResource
  self.model_class = "Promotable::Adjustment"
  self.title = :label
  self.description = "Discount line applied to a host object (order, cart, etc.)."

  def fields
    field :id, as: :id

    field :promotion,        as: :belongs_to, readonly: true
    field :promotion_action, as: :belongs_to, readonly: true

    field :adjustable, as: :belongs_to, readonly: true, polymorphic: true
    field :amount,   as: :number, readonly: true, step: 0.0001
    field :label,    as: :text
    field :eligible, as: :boolean

    field :client_id, as: :number, readonly: true, help: "Inherited from parent Promotion."

    field :metadata, as: :key_value, hide_on: :index,
          key_label: "Attribute", value_label: "Value"

    field :created_at, as: :date_time, readonly: true
  end
end
