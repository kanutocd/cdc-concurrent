# frozen_string_literal: true

module CDC
  module Concurrent
    # Normalizes values returned by Async tasks into ProcessorResult objects.
    #
    # ResultCollector keeps runtime pools tolerant of processors that either
    # return a CDC::Core::ProcessorResult directly or return a plain Ruby value.
    # Plain values are wrapped as successful ProcessorResult instances, while
    # raised errors are represented as failure results.
    class ResultCollector
      # Normalizes a processor return value into a ProcessorResult.
      #
      # @param value [Object] Value returned by a processor or an existing ProcessorResult.
      # @return [CDC::Core::ProcessorResult] Existing ProcessorResult or success result wrapping the value.
      def self.normalize(value)
        return value if value.is_a?(CDC::Core::ProcessorResult)

        CDC::Core::ProcessorResult.success(value)
      rescue StandardError => e
        failure(e)
      end

      # Wraps an exception as a failed ProcessorResult.
      #
      # @param error [Exception] Error raised while processing an event.
      # @return [CDC::Core::ProcessorResult] Failure result containing the supplied error.
      def self.failure(error)
        CDC::Core::ProcessorResult.failure(error)
      end
    end
  end
end
