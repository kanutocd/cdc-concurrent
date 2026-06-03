# frozen_string_literal: true

module CDC
  module Concurrent
    # High-level concurrent runtime facade for cdc-core processors.
    class Runtime
      # @param processor [CDC::Core::Processor]
      # @param concurrency [Integer]
      # @param timeout [Float, nil]
      # @param preserve_order [Boolean]
      def initialize(processor:, concurrency: 100, timeout: nil, preserve_order: true)
        @processor_pool = ProcessorPool.new(processor:, concurrency:, timeout:, preserve_order:)
        @transaction_pool = TransactionPool.new(processor:, concurrency:, timeout:, preserve_order:)
        @router = Router.new(processor_pool: @processor_pool, transaction_pool: @transaction_pool)
        @shutdown = false
      end

      # @param item [Object]
      # @return [Object]
      def process(item)
        raise ShutdownError, "runtime has been shut down" if @shutdown

        @router.process(item)
      end

      # @param events [Array<CDC::Core::ChangeEvent>]
      # @return [Array<CDC::Core::ProcessorResult>]
      def process_many(events)
        process(events)
      end

      # @param transaction [CDC::Core::TransactionEnvelope]
      # @return [CDC::Core::ProcessorResult]
      def process_transaction(transaction)
        process(transaction)
      end

      # @return [void]
      def shutdown
        return if @shutdown

        @shutdown = true
        @processor_pool.shutdown
        @transaction_pool.shutdown
      end
    end
  end
end
