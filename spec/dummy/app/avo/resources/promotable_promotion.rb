class Avo::Resources::PromotablePromotion < Avo::BaseResource
  self.model_class = "Promotable::Promotion"
  self.title = :name
  self.description = "A named promotion with rules, actions, and codes."
  self.includes = [ :rules, :actions, :codes ]

  self.search = {
    query: -> {
      query.where("name LIKE :q OR description LIKE :q", q: "%#{params[:q]}%")
    }
  }

  def fields
    panel do
      field :id, as: :id

      field :name,        as: :text,     required: true
      field :description, as: :textarea, hide_on: :index
      field :promotion_type, as: :text, help: "Freeform tag (e.g. 'seasonal', 'welcome')."

      field :active,    as: :boolean
      field :stackable, as: :boolean, help: "May this promotion stack with others?"

      field :priority, as: :number, help: "Lower runs first when stacking."

      field :starts_at,  as: :date_time
      field :expires_at, as: :date_time

      field :usage_limit,    as: :number, help: "Total redemption cap. Blank = unlimited."
      field :per_user_limit, as: :number, help: "Per-user redemption cap. Blank = unlimited."
      field :usage_count,    as: :number, readonly: true, hide_on: %i[new edit]

      field :client_id, name: 'Client', as: :select, required: false,
      options: -> {
        ::Client.pluck(:name, :id).map { |name, id| [ name, id ] }.to_h
      },
      default_value: -> { Promotable.configuration&.current_tenant&.id },
      help: "Tenant that this promotion is scoped to. Blank = global."
      field :metadata, as: :key_value, hide_on: :index,
            key_label: "Attribute", value_label: "Value",
            help: "Freeform JSON metadata for downstream reporting."
    end

    tabs do
      field :rules,       as: :has_many
      # `:actions` collides with Avo's reserved bulk-action routes
      # (`/resources/:name/:id/actions/(:action_id)` → `Avo::ActionsController`).
      # We expose the promotion's `has_many :actions` under a non-conflicting
      # URL segment via `for_attribute:`.
      field :discount_actions, as: :has_many,
                               for_attribute: :actions,
                               use_resource: "Avo::Resources::PromotableAction",
                               name: 'Actions'
      field :codes,       as: :has_many
      field :adjustments, as: :has_many
    end
  end
end
