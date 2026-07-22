ENV["RAILS_ENV"] ||= "test"

require_relative "../spec/dummy/config/environment"
abort("The Rails environment is running in production mode!") if Rails.env.production?

ActiveRecord::Migrator.migrations_paths = [ File.expand_path("../spec/dummy/db/migrate", __dir__) ]
ActiveRecord::Migrator.migrations_paths << File.expand_path("../db/migrate", __dir__)
ActiveRecord::Tasks::DatabaseTasks.migrations_paths = ActiveRecord::Migrator.migrations_paths

require "rspec/rails"

begin
  ActiveRecord::Tasks::DatabaseTasks.migrate

  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

Dir[File.join(__dir__, "support/**/*.rb")].sort.each { |f| require f }

RSpec.configure do |config|
  config.use_transactional_fixtures = true

  config.include PromotableTestHelper

  config.before do
    Promotable.configuration = Promotable::Configuration.new
  end

  config.filter_rails_from_backtrace!
end
