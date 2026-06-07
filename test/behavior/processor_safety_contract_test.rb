# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../support/processors"
require_relative "../support/events"

class ProcessorSafetyContractTest < Minitest::Test
  include EventFixtures

  def test_processor_must_declare_concurrent_safety
    assert_raises(CDC::Concurrent::UnsafeProcessorError) do
      CDC::Concurrent::ProcessorPool.new(processor: UnsafeConcurrentProcessor.new, concurrency: 1)
    end
  end

  def test_concurrent_safety_is_inherited_by_instances
    assert_predicate SafeConcurrentProcessor.new, :concurrent_safe?
  end

  def test_concurrent_safe_processor_can_be_processed
    pool = CDC::Concurrent::ProcessorPool.new(processor: SafeConcurrentProcessor.new, concurrency: 1)

    result = pool.process(change_event)

    assert_predicate result, :success?
  ensure
    pool&.shutdown
  end
end
