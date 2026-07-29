class Avo::Resources::Client < Avo::BaseResource
  self.title = :name
  self.description = "Tenant that owns promotions, users, and orders."
  self.search = {
    query: -> { query.where("name ILIKE ?", "%#{params[:q]}%") }
  }

  def fields
    field :id, as: :id
    field :name, as: :text, required: true
    field :client_type, as: :select, enum: ::Client.client_types
    field :currency, as: :text
    field :prefix_code, as: :text
    field :source, as: :text
    field :support_number, as: :text

    field :users, as: :has_many
    field :orders, as: :has_many
  end
end
