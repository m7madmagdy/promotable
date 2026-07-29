class Avo::Resources::Order < Avo::BaseResource
  self.title = :number
  self.description = "Promotable order backed by acts_as_promotable."

  def fields
    field :id, as: :id
    field :number, as: :text
    field :status, as: :text
    field :source, as: :text

    field :items_total,           as: :number
    field :delivery_fee,          as: :number
    field :shipping_cost,         as: :number
    field :total,                 as: :number
    field :total_after_discounts, as: :number
    field :item_count,            as: :number

    field :client, as: :belongs_to
    field :user,   as: :belongs_to
    field :line_items, as: :has_many
  end
end
