# frozen_string_literal: true

module CDC
  module Concurrent
    # Base cdc-concurrent error.
    class Error < StandardError; end

    # Raised when a processor has not declared itself concurrent-safe.
    class UnsafeProcessorError < Error; end

    # Raised when work is submitted after shutdown.
    class ShutdownError < Error; end

    # Raised when the runtime receives an unsupported work item.
    class UnsupportedWorkItemError < Error; end

    # Raised when processing exceeds the configured timeout.
    class TimeoutError < Error; end
  end
end
