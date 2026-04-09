ENV["RAILS_ENV"] = "test"

require_relative "../test/dummy/config/environment"
ActiveRecord::Migrator.migrations_paths = [ File.expand_path("../test/dummy/db/migrate", __dir__) ]
ActiveRecord::Migrator.migrations_paths << File.expand_path("../db/migrate", __dir__)
require "rails/test_help"

module PromotableTestHelper
  def create_promotion(attrs = {})
    Promotable::Promotion.create!({
      name: "Test Promotion",
      active: true,
      starts_at: 1.day.ago,
      expires_at: 1.day.from_now
    }.merge(attrs))
  end

  def create_order(attrs = {})
    Order.create!({
      total_amount: 100,
      shipping_cost: 10,
      item_count: 3
    }.merge(attrs))
  end

  def create_user(attrs = {})
    User.create!({ name: "Test User" }.merge(attrs))
  end

  def create_promotion_with_code(code: "SAVE10", **promo_attrs)
    promo = create_promotion(**promo_attrs)
    promo.codes.create!(code: code)
    promo
  end
end

class ActiveSupport::TestCase
  include PromotableTestHelper

  setup do
    Promotable.configuration = Promotable::Configuration.new
  end
end
