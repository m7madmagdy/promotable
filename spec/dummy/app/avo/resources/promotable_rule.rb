class Avo::Resources::PromotableRule < Avo::BaseResource
  self.model_class = "Promotable::Rules::Base"
  self.title = :id
  self.description = "Eligibility condition attached to a Promotion. All rules must pass."

  def fields
    field :id, as: :id

    field :promotion, as: :belongs_to, required: true

    field :type,
          as: :select,
          required: true,
          options: -> { Avo::Resources::PromotableRule.registered_rule_options },
          include_blank: "— pick a rule type —",
          help: "Choose from the classes registered in `Promotable.configuration.rule_registry`."

    field :preferences,
          as: :key_value,
          key_label: "Preference",
          value_label: "Value",
          action_text: "Add preference",
          help: rule_preferences_help
  end

  def self.registered_rule_options
    Promotable.configuration.rule_registry.all.each_with_object({}) do |(_key, klass), memo|
      label = klass.respond_to?(:display_name) ? klass.display_name : klass.name.demodulize
      memo[label] = klass.name
    end
  rescue StandardError
    {}
  end

  private

  def rule_preferences_help
    schema = Promotable.configuration.rule_registry.all.each_with_object({}) do |(_key, klass), memo|
      next unless klass.respond_to?(:preference_fields) && klass.preference_fields.any?

      memo[klass.name] = klass.preference_fields.map { |f| "#{f[:name]}:#{f[:type]}" }.join(", ")
    end
    return "Preferences are class-specific — see registry." if schema.empty?

    schema.map { |name, fields| "• #{name}: #{fields}" }.join("\n")
  rescue StandardError
    "Preferences are class-specific — see registry."
  end
end
