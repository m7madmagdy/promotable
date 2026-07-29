Promotable.configure do |config|
  # Whether multiple promotions can stack on the same promotable.
  # config.allow_stacking = false

  # Whether promotion codes are case-sensitive.
  # config.code_case_sensitive = true

  # ------------------------------------------------------------------------
  # Multitenancy
  # ------------------------------------------------------------------------
  # Host model that owns promotions. Backed by acts_as_tenant on client_id.
  # config.tenant_model_name = "Client"

  # When true, all Promotable queries require ActsAsTenant.current_tenant.
  # When false (default), global (client_id: nil) records are also visible.
  config.require_tenant = false

  # Optional: resolve the current tenant globally when acts_as_tenant is not set.
  # config.current_tenant_resolver = -> { Current.client }

  # ------------------------------------------------------------------------
  # Contract enforcement
  # ------------------------------------------------------------------------
  # How to react when a host object is missing an optional contract method
  # (e.g. Order#promotable_country used by CountryRule). One of :skip, :log, :raise.
  # config.on_missing_contract_method = :log

  # ------------------------------------------------------------------------
  # Custom rules and actions
  # ------------------------------------------------------------------------
  # config.rule_registry.register(:my_custom_rule, MyApp::MyCustomRule)
  # config.action_registry.register(:my_custom_action, MyApp::MyCustomAction)
end
