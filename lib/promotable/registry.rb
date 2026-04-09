require "concurrent/map"

module Promotable
  class Registry
    attr_reader :base_class

    def initialize(base_class)
      @base_class = base_class
      @items = Concurrent::Map.new
    end

    def register(key, klass)
      validate!(klass)
      @items[key.to_sym] = klass
      self
    end

    def unregister(key)
      @items.delete(key.to_sym)
    end

    def resolve(key)
      @items.fetch(key.to_sym) do
        raise ArgumentError, "No #{base_class.name} registered under :#{key}. Available: #{keys.join(', ')}"
      end
    end

    def registered?(key)
      @items.key?(key.to_sym)
    end

    def keys
      @items.keys
    end

    def all
      @items.each_pair.to_h
    end

    def clear!
      @items.clear
    end

    private

    def validate!(klass)
      return if klass < base_class

      raise ArgumentError,
        "#{klass} must be a subclass of #{base_class.name}"
    end
  end
end
