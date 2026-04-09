module Promotable
  module Generators
    class ActionGenerator < Rails::Generators::NamedBase
      source_root File.expand_path("templates", __dir__)

      desc "Generates a custom Promotable action subclass."

      argument :preferences, type: :array, default: [],
               banner: "field:type field:type"

      def create_action_file
        template "action.rb.tt", File.join("app/models", class_path.join("/"), "#{file_name}_action.rb")
      end

      def create_test_file
        template "action_test.rb.tt", File.join("test/models", class_path.join("/"), "#{file_name}_action_test.rb")
      end

      def display_registration_instructions
        say ""
        say "Action generated! Register it in config/initializers/promotable.rb:", :green
        say ""
        say "  config.action_registry.register(:#{file_name}, #{class_name}Action)"
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
