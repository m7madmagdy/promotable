require "promotable/version"
require "promotable/engine"
require "promotable/errors"
require "promotable/registry"
require "promotable/configuration"
require "promotable/contract_resolver"
require "promotable/tenant_scoped"
require "promotable/acts_as_promotable"
require "promotable/acts_as_promoter"
require "promotable/evaluator"
require "promotable/applicator"
require "promotable/code_redeemer"

module Promotable
  class << self
    attr_accessor :configuration

    def configure
      self.configuration ||= Configuration.new
      yield(configuration) if block_given?
    end

    def reset_configuration!
      self.configuration = Configuration.new
    end
  end
end
