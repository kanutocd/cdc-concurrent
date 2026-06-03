# frozen_string_literal: true

module CDC
  module Concurrent
    # Normalizes values returned by concurrent workers.
    class ResultCollector
      # @param value [Object]
      # @return [CDC::Core::ProcessorResult]
      def self.normalize(value)
        return value if value.is_a?(CDC::Core::ProcessorResult)

        CDC::Core::ProcessorResult.success(value)
      rescue StandardError => e
        failure(e)
      end

      # @param error [Exception]
      # @return [CDC::Core::ProcessorResult]
      def self.failure(error)
        CDC::Core::ProcessorResult.failure(error)
      end
    end
  end
end
