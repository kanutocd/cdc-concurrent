# frozen_string_literal: true

module CDC
  module Concurrent
    # Immutable configuration for concurrent runtimes.
    class Configuration
      attr_reader :concurrency, :timeout, :preserve_order

      # @param concurrency [Integer] maximum concurrent tasks.
      # @param timeout [Float, nil] optional timeout.
      # @param preserve_order [Boolean] whether batch results preserve input order.
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
