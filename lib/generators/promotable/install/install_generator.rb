module Promotable
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Installs the Promotable engine: copies migrations and creates the initializer."

      class_option :tenant_model, type: :string, default: "Client",
        desc: "Host model that owns promotions (e.g. Client, Account, Organization)."
      class_option :require_tenant, type: :boolean, default: false,
        desc: "When true, every Promotable query requires an ActsAsTenant.current_tenant."

      def copy_initializer
        @tenant_model   = options[:tenant_model]
        @require_tenant = options[:require_tenant]
        template "initializer.rb", "config/initializers/promotable.rb"
      end

      def install_migrations
        rake "promotable:install:migrations"
      end

      def display_post_install
        say ""
        say "Promotable has been installed successfully!", :green
        say ""
        say "Next steps:"
        say "  1. Run migrations:    rails db:migrate"
        say "  2. Add to your Order: acts_as_promotable"
        say "  3. Add to your User:  acts_as_promoter"
        say "  4. Customize config/initializers/promotable.rb"
        say ""
      end
    end
  end
end
