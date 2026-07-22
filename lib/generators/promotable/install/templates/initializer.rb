Promotable.configure do |config|
  # Whether multiple promotions can stack on the same promotable.
  # config.allow_stacking = false

  # Whether promotion codes are case-sensitive.
  # config.code_case_sensitive = true

  # Optional: resolve the current tenant (Client) globally.
  # config.current_tenant_resolver = -> { Current.client }

  # Optional: tenant model name used by your host application.
  # config.tenant_model_name = "Client"

  # Register custom rules:
  # config.rule_registry.register(:my_custom_rule, MyApp::MyCustomRule)

  # Register custom actions:
  # config.action_registry.register(:my_custom_action, MyApp::MyCustomAction)
end
