class Avo::Resources::User < Avo::BaseResource
  self.title = :name
  self.description = "Customer account belonging to a Client tenant."

  def fields
    field :id, as: :id
    field :name, as: :text, required: true
    field :email, as: :text
    field :mobile_number, as: :text
    field :date_of_birth, as: :date
    field :verified, as: :boolean
    field :promotion_group, as: :text

    field :client, as: :belongs_to
    field :orders, as: :has_many
  end
end
