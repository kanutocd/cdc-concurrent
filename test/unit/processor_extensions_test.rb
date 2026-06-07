# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../support/processors"

class ProcessorExtensionsTest < Minitest::Test
  def test_concurrent_safe_declaration
    assert_predicate SafeConcurrentProcessor.new, :concurrent_safe?
    refute_predicate UnsafeConcurrentProcessor.new, :concurrent_safe?
  end
end
