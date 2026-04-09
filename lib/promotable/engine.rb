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
  end
end
