module Promotable
  # Resolves optional host contract methods on a promotable/promoter object,
  # honoring `Promotable.configuration.on_missing_contract_method`.
  #
  # Modes:
  #   :skip  — silently return nil
  #   :log   — log a warning once per (klass, method) pair and return nil
  #   :raise — raise Promotable::ContractError
  #
  # Usage:
  #   items = Promotable::ContractResolver.call(order, :promotable_items)
  module ContractResolver
    @warned = Concurrent::Map.new

    class << self
      def call(target, method_name, *args, **kwargs)
        return target.public_send(method_name, *args, **kwargs) if target.respond_to?(method_name)

        handle_missing(target, method_name)
      end

      # Clears the per-process "already-warned" registry. Primarily used in tests.
      def reset_warnings!
        @warned = Concurrent::Map.new
      end

      private

      def handle_missing(target, method_name)
        mode = Promotable.configuration&.on_missing_contract_method || :log

        case mode
        when :skip
          nil
        when :raise
          raise Promotable::ContractError,
                "#{target.class} does not implement optional contract method ##{method_name}"
        else # :log (also the fallback for unknown modes)
          warn_once(target.class, method_name)
          nil
        end
      end

      def warn_once(klass, method_name)
        key = "#{klass}##{method_name}"
        return if @warned[key]

        @warned[key] = true
        logger = Promotable.configuration&.logger
        message = "[Promotable] #{klass} does not implement optional contract method ##{method_name}; returning nil."
        logger ? logger.warn(message) : warn(message)
      end
    end
  end
end
