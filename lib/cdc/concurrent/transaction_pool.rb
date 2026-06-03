# frozen_string_literal: true

module CDC
  module Concurrent
    # Processes TransactionEnvelope events as a single ordering-preserving unit.
    class TransactionPool
      # @param processor [CDC::Core::Processor]
      # @param concurrency [Integer]
      # @param timeout [Float, nil]
      # @param preserve_order [Boolean]
      def initialize(processor:, concurrency: 100, timeout: nil, preserve_order: true)
        @processor_pool = ProcessorPool.new(processor:, concurrency:, timeout:, preserve_order:)
      end

      # @param transaction [CDC::Core::TransactionEnvelope]
      # @return [CDC::Core::ProcessorResult]
      def process(transaction)
        results = @processor_pool.process_many(transaction.events).freeze
        failure = results.find(&:failure?)

        return CDC::Core::ProcessorResult.failure(failure.error, event: results) if failure

        CDC::Core::ProcessorResult.success(results)
      end

      # @return [void]
      def shutdown
        @processor_pool.shutdown
      end
    end
  end
end
