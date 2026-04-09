Promotable.configure do |config|
  # Maximum number of promotions that can be applied to a single promotable.
  # config.max_promotions_per_promotable = 5

  # Whether multiple promotions can stack on the same promotable.
  # config.allow_stacking = true

  # Whether promotion codes are case-sensitive.
  # config.code_case_sensitive = false

  # Register custom rules:
  # config.rule_registry.register(:my_custom_rule, MyApp::MyCustomRule)

  # Register custom actions:
  # config.action_registry.register(:my_custom_action, MyApp::MyCustomAction)
end
