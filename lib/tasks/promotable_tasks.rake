namespace :promotable do
  desc "Show registered promotion rules and actions"
  task stats: :environment do
    config = Promotable.configuration

    puts "Promotable Engine Stats"
    puts "=" * 40

    if config
      puts "\nRegistered Rules:"
      if config.rule_registry.keys.any?
        config.rule_registry.all.each do |key, klass|
          puts "  :#{key} => #{klass.name}"
        end
      else
        puts "  (none)"
      end

      puts "\nRegistered Actions:"
      if config.action_registry.keys.any?
        config.action_registry.all.each do |key, klass|
          puts "  :#{key} => #{klass.name}"
        end
      else
        puts "  (none)"
      end
    end

    puts "\nPromotion counts:"
    puts "  Total:    #{Promotable::Promotion.count}"
    puts "  Active:   #{Promotable::Promotion.active.count}"
    puts "  Current:  #{Promotable::Promotion.current.count}"
    puts "  Codes:    #{Promotable::PromotionCode.count}"
  end
end
