# frozen_string_literal: true

module CDC
  module Concurrent
    # Immutable configuration for cdc-concurrent runtime pools.
    #
    # A Configuration instance captures the execution limits shared by
    # ProcessorPool, TransactionPool, and Runtime. Instances are frozen so pool
    # behavior cannot change while work is being processed.
    class Configuration
      # @return [Integer] Maximum number of Async tasks allowed to run concurrently.
      # @return [Float, nil] Optional per-event processing timeout in seconds.
      # @return [Boolean] Whether batch results should be returned in input order.
      attr_reader :concurrency, :timeout, :preserve_order

      # Builds a frozen runtime configuration.
      #
      # @param concurrency [Integer] Maximum number of Async tasks allowed to run at once.
      # @param timeout [Float, nil] Optional per-event processing timeout in seconds.
      # @param preserve_order [Boolean] Whether batch results should preserve input order.
      # @raise [ArgumentError] If concurrency is not a positive Integer.
      # @return [void] Does not return a useful value.
      def initialize(concurrency: 100, timeout: nil, preserve_order: true)
        raise ArgumentError, "concurrency must be an Integer" unless concurrency.is_a?(Integer)
        raise ArgumentError, "concurrency must be greater than zero" unless concurrency.positive?

        @concurrency = concurrency
        @timeout = timeout
        @preserve_order = preserve_order
        freeze
      end
    end
  end
end
