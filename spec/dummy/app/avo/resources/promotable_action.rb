class Avo::Resources::PromotableAction < Avo::BaseResource
  self.model_class = "Promotable::Actions::Base"
  self.title = :id
  self.description = "Discount to apply when a Promotion is eligible."

  def fields
    field :id, as: :id

    field :promotion, as: :belongs_to, required: true

    field :type,
          as: :select,
          required: true,
          options: -> { Avo::Resources::PromotableAction.registered_action_options },
          include_blank: "— pick an action type —",
          help: "Choose from the classes registered in `Promotable.configuration.action_registry`."

    field :preferences,
          as: :key_value,
          key_label: "Preference",
          value_label: "Value",
          action_text: "Add preference",
          help: action_preferences_help

    field :adjustments, as: :has_many
  end

  def self.registered_action_options
    Promotable.configuration.action_registry.all.each_with_object({}) do |(_key, klass), memo|
      label = klass.respond_to?(:display_name) ? klass.display_name : klass.name.demodulize
      memo[label] = klass.name
    end
  rescue StandardError
    {}
  end

  private

  def action_preferences_help
    schema = Promotable.configuration.action_registry.all.each_with_object({}) do |(_key, klass), memo|
      next unless klass.respond_to?(:preference_fields) && klass.preference_fields.any?

      memo[klass.name] = klass.preference_fields.map { |f| "#{f[:name]}:#{f[:type]}" }.join(", ")
    end
    return "Preferences are class-specific — see registry." if schema.empty?

    schema.map { |name, fields| "• #{name}: #{fields}" }.join("\n")
  rescue StandardError
    "Preferences are class-specific — see registry."
  end
end
