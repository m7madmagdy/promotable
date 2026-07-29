require "concurrent/map"

module Promotable
  class Registry
    def initialize(base_class)
      # Store the class NAME rather than the Class object so registrations
      # survive Rails code reloading in development. Zeitwerk replaces the
      # actual Class objects on every reload; a captured reference would go
      # stale and cause `subclass < old_base_class` to return false, raising
      # spurious "must be a subclass of ..." errors on the next request.
      @base_class_name = base_class.is_a?(String) || base_class.is_a?(Symbol) ? base_class.to_s : base_class.name
      @items = Concurrent::Map.new
    end

    # Always resolves to the *current* base class through the constant
    # lookup, so callers see the reloaded class in development.
    def base_class
      @base_class_name.constantize
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
      # Compare by name to remain correct across Rails reloads. `klass <
      # base_class` would fail after a reload because Zeitwerk rebuilds
      # every Class object, so the ancestor chain no longer includes the
      # *old* base-class reference we would otherwise be comparing against.
      return if klass.ancestors.any? { |a| a.name == @base_class_name }

      raise ArgumentError,
        "#{klass} must be a subclass of #{@base_class_name}"
    end
  end
end
