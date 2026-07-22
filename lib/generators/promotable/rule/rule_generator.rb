module Promotable
  module Generators
    class RuleGenerator < Rails::Generators::NamedBase
      source_root File.expand_path("templates", __dir__)

      desc "Generates a custom Promotable rule subclass."

      argument :preferences, type: :array, default: [],
               banner: "field:type field:type"

      def create_rule_file
        template "rule.rb.tt", File.join("app/models", class_path.join("/"), "#{file_name}_rule.rb")
      end

      def create_test_file
        template "rule_spec.rb.tt", File.join("spec/models", class_path.join("/"), "#{file_name}_rule_spec.rb")
      end

      def display_registration_instructions
        say ""
        say "Rule generated! Register it in config/initializers/promotable.rb:", :green
        say ""
        say "  config.rule_registry.register(:#{file_name}, #{class_name}Rule)"
        say ""
      end

      private

      def parsed_preferences
        preferences.map do |pref|
          name, type = pref.split(":")
          { name: name, type: type || "string" }
        end
      end
    end
  end
end
