module Promotable
  class Engine < ::Rails::Engine
    isolate_namespace Promotable

    initializer "promotable.configure" do |app|
      Promotable.configuration ||= Configuration.new
    end

    initializer "promotable.active_record" do
      ActiveSupport.on_load(:active_record) do
        include Promotable::ActsAsPromotable
        include Promotable::ActsAsPromoter
      end
    end

    initializer "promotable.append_migrations" do |app|
      config.paths["db/migrate"].expanded.each do |expanded_path|
        app.config.paths["db/migrate"] << expanded_path unless app.config.paths["db/migrate"].include?(expanded_path)
      end
    end
  end
end
