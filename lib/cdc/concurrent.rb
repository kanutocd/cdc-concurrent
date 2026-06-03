# frozen_string_literal: true

require "async"
require "async/semaphore"
require "cdc/core"

require_relative "concurrent/version"
require_relative "concurrent/errors"
require_relative "concurrent/configuration"
require_relative "concurrent/processor_extensions"
require_relative "concurrent/result_collector"
require_relative "concurrent/processor_pool"
require_relative "concurrent/transaction_pool"
require_relative "concurrent/router"
require_relative "concurrent/runtime"

module CDC
  # Optional concurrent runtime adapter for cdc-core processors.
  module Concurrent
  end
end
