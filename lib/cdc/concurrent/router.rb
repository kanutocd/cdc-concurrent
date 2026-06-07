# frozen_string_literal: true

module CDC
  module Concurrent
    # Routes CDC work items to the appropriate concurrent execution pool.
    #
    # Router is intentionally small. It keeps Runtime focused on lifecycle while
    # preserving the distinction between individual events, transaction envelopes,
    # and event batches.
    class Router
      # Builds a router using existing processor and transaction pools.
      #
      # @param processor_pool [ProcessorPool] Pool used for individual ChangeEvent work and event batches.
      # @param transaction_pool [TransactionPool] Pool used for TransactionEnvelope work.
      # @return [void] Does not return a useful value.
      def initialize(processor_pool:, transaction_pool:)
        @processor_pool = processor_pool
        @transaction_pool = transaction_pool
      end

      # Dispatches a supported work item to its matching pool.
      #
      # @param item [CDC::Core::ChangeEvent, CDC::Core::TransactionEnvelope, Array<CDC::Core::ChangeEvent>] Work item to process.
      # @raise [UnsupportedWorkItemError] If the item cannot be routed by cdc-concurrent.
      # @return [CDC::Core::ProcessorResult, Array<CDC::Core::ProcessorResult>] Processing result for the supplied item.
      def process(item)
        case item
        when CDC::Core::ChangeEvent
          @processor_pool.process(item)
        when CDC::Core::TransactionEnvelope
          @transaction_pool.process(item)
        when Array
          @processor_pool.process_many(item)
        else
          raise UnsupportedWorkItemError, "unsupported CDC work item: #{item.class}"
        end
      end
    end
  end
end
