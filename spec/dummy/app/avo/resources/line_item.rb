class Avo::Resources::LineItem < Avo::BaseResource
  self.title = -> {
    "Line Item ##{record.id} - #{record.variant_sku}"
  }
  self.description = "Item line on an Order (polymorphic orderable)."

  def fields
    field :id, as: :id
    field :variant_sku,          as: :text, required: true
    field :quantity,             as: :number
    field :price,                as: :number
    field :price_after_discount, as: :number

    field :orderable, as: :belongs_to, polymorphic_as: :orderable, types: [ ::Order ]
  end
end
