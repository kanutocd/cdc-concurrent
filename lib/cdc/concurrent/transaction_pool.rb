# frozen_string_literal: true

module CDC
  module Concurrent
    # Processes TransactionEnvelope events as one logical unit.
    #
    # TransactionPool delegates the envelope's events to ProcessorPool while
    # preserving the envelope-level success/failure contract. Event work may run
    # concurrently, but the transaction result is returned as a single
    # CDC::Core::ProcessorResult.
    class TransactionPool
      # Builds a transaction pool backed by an Async processor pool.
      #
      # @param processor [CDC::Core::Processor] Processor instance that declares concurrent_safe!.
      # @param concurrency [Integer] Maximum number of Async tasks allowed to run at once.
      # @param timeout [Float, nil] Optional per-event processing timeout in seconds.
      # @param preserve_order [Boolean] Whether event results should preserve transaction event order.
      # @raise [UnsafeProcessorError] If the processor does not declare concurrent_safe!.
      # @return [void] Does not return a useful value.
      def initialize(processor:, concurrency: 100, timeout: nil, preserve_order: true)
        @processor_pool = ProcessorPool.new(processor:, concurrency:, timeout:, preserve_order:)
      end

      # Processes all events inside a transaction envelope.
      #
      # @param transaction [CDC::Core::TransactionEnvelope] Transaction envelope whose events should be processed.
      # @return [CDC::Core::ProcessorResult] Success result containing event results
      #         or failure result for the first failed event.Z
      def process(transaction)
        results = @processor_pool.process_many(transaction.events).freeze
        failure = results.find(&:failure?)

        return CDC::Core::ProcessorResult.failure(failure.error, event: results) if failure

        CDC::Core::ProcessorResult.success(results)
      end

      # Shuts down the underlying processor pool.
      #
      # @return [void] Does not return a useful value.
      def shutdown
        @processor_pool.shutdown
      end
    end
  end
end
