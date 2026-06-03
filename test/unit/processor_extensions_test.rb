# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../support/processors"

class ProcessorExtensionsTest < Minitest::Test
  def test_concurrent_safe_declaration
    assert SafeConcurrentProcessor.new.concurrent_safe?
    refute UnsafeConcurrentProcessor.new.concurrent_safe?
  end
end
