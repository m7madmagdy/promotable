module Promotable
  class Engine < ::Rails::Engine
    isolate_namespace Promotable

    initializer "promotable.configure" do |app|
      Promotable.configuration ||= Configuration.new
    end

    # Mirror the gem's `require_tenant` setting into acts_as_tenant's global
    # configuration so its default_scope raises `NoTenantSet` when appropriate.
    initializer "promotable.acts_as_tenant", after: "promotable.configure" do
      ActsAsTenant.configure do |aat|
        aat.require_tenant = Promotable.configuration.require_tenant
      end
    end

    initializer "promotable.active_record" do
      ActiveSupport.on_load(:active_record) do
        include Promotable::ActsAsPromotable
        include Promotable::ActsAsPromoter
      end
    end

    # Register the built-in rules and actions once the host app's autoloader
    # is ready. `to_prepare` re-runs on every code reload in development so
    # the registry stays in sync with reloaded class objects.
    config.to_prepare do
      Promotable.configuration.register_defaults!
    end
  end
end
