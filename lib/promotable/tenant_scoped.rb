require "acts_as_tenant"

module Promotable
  # Included by every tenant-scoped Promotable model (Promotion,
  # PromotionCode, CodeUsage, Adjustment). Configures acts_as_tenant with
  # the host-app tenant class, always allows global records (nil client_id),
  # and re-declares the belongs_to with the correct class_name so single-
  # table lookups resolve regardless of how the host names their tenant model.
  #
  # DB column is always `client_id`; only the associated class varies
  # (via `Promotable.configuration.tenant_model_name`).
  module TenantScoped
    extend ActiveSupport::Concern

    included do
      config = Promotable.configuration ||= Promotable::Configuration.new

      acts_as_tenant :client,
                     class_name: config.tenant_model_name,
                     optional: true,
                     has_global_records: true
    end
  end
end
