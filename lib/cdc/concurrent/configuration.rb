# frozen_string_literal: true

module CDC
  module Concurrent
    # Immutable configuration for concurrent runtimes.
    Configuration = Data.define(:concurrency, :timeout, :preserve_order) do
      # @param concurrency [Integer] maximum concurrent tasks.
      # @param timeout [Float, nil] optional timeout.
      # @param preserve_order [Boolean] whether batch results preserve input order.
      def initialize(concurrency: 100, timeout: nil, preserve_order: true)
        raise ArgumentError, "concurrency must be an Integer" unless concurrency.is_a?(Integer)
        raise ArgumentError, "concurrency must be greater than zero" unless concurrency.positive?

        super
        freeze
      end
    end
  end
end
