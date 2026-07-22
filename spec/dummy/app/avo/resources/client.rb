class Avo::Resources::Client < Avo::BaseResource
  # self.avatar = {
  #   source: :avatar
  # }
  # self.includes = []
  # self.attachments = []
  # self.search = {
  #   query: -> { query.ransack(id_eq: q, m: "or").result(distinct: false) }
  # }

  def fields
    field :id, as: :id
    field :name, as: :text

    field :users, as: :has_many
    field :orders, as: :has_many
  end
end
