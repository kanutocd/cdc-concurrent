# frozen_string_literal: true

module CDC
  module Concurrent
    # Routes CDC work items to the correct concurrent pool.
    class Router
      # @param processor_pool [ProcessorPool]
      # @param transaction_pool [TransactionPool]
      def initialize(processor_pool:, transaction_pool:)
        @processor_pool = processor_pool
        @transaction_pool = transaction_pool
      end

      # @param item [Object]
      # @return [Object]
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
