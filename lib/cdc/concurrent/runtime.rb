# frozen_string_literal: true

module CDC
  module Concurrent
    # High-level concurrent runtime facade for cdc-core processors.
    #
    # Runtime owns the public lifecycle for cdc-concurrent. It wires together the
    # event processor pool, transaction pool, and router so callers can submit
    # individual events, batches, or transaction envelopes through one object.
    class Runtime
      # Builds a concurrent runtime for one processor.
      #
      # @param processor [CDC::Core::Processor] Processor instance that declares concurrent_safe!.
      # @param concurrency [Integer] Maximum number of Async tasks allowed to run at once.
      # @param timeout [Float, nil] Optional per-event processing timeout in seconds.
      # @param preserve_order [Boolean] Whether batch results should preserve input order.
      # @raise [UnsafeProcessorError] If the processor does not declare concurrent_safe!.
      # @return [void] Does not return a useful value.
      def initialize(processor:, concurrency: 100, timeout: nil, preserve_order: true)
        @processor_pool = ProcessorPool.new(processor:, concurrency:, timeout:, preserve_order:)
        @transaction_pool = TransactionPool.new(processor:, concurrency:, timeout:, preserve_order:)
        @router = Router.new(processor_pool: @processor_pool, transaction_pool: @transaction_pool)
        @shutdown = false
      end

      # Processes a supported work item through the runtime router.
      #
      # @param item [CDC::Core::ChangeEvent, CDC::Core::TransactionEnvelope, Array<CDC::Core::ChangeEvent>] Work item to process.
      # @raise [ShutdownError] If the runtime has already been shut down.
      # @raise [UnsupportedWorkItemError] If the item cannot be routed by cdc-concurrent.
      # @return [CDC::Core::ProcessorResult, Array<CDC::Core::ProcessorResult>] Processing result for the supplied item.
      def process(item)
        raise ShutdownError, "runtime has been shut down" if @shutdown

        @router.process(item)
      end

      # Processes a batch of change events.
      #
      # @param events [Array<CDC::Core::ChangeEvent>] Events to process through the processor pool.
      # @return [Array<CDC::Core::ProcessorResult>] Frozen array of normalized processor results.
      def process_many(events)
        process(events)
      end

      # Processes a transaction envelope as one logical work item.
      #
      # @param transaction [CDC::Core::TransactionEnvelope] Transaction whose events should be processed together.
      # @return [CDC::Core::ProcessorResult] Success result containing event results or failure result for the first failed event.
      def process_transaction(transaction)
        process(transaction)
      end

      # Shuts down the runtime and its underlying pools.
      #
      # @return [void] Does not return a useful value.
      def shutdown
        return if @shutdown

        @shutdown = true
        @processor_pool.shutdown
        @transaction_pool.shutdown
      end
    end
  end
end
