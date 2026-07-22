class Avo::Resources::Order < Avo::BaseResource
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
    field :total_amount, as: :number
    field :total_after_discounts, as: :number

    field :shipping_cost, as: :number
    field :item_count, as: :number

    field :user, as: :belongs_to
    field :client, as: :belongs_to
  end
end
