# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../support/processors"
require_relative "../support/events"

class ProcessorPoolUnitTest < Minitest::Test
  include EventFixtures

  def test_rejects_unsafe_processor
    error = assert_raises(CDC::Concurrent::UnsafeProcessorError) do
      CDC::Concurrent::ProcessorPool.new(processor: UnsafeConcurrentProcessor.new, concurrency: 1)
    end

    assert_equal "UnsafeConcurrentProcessor must declare concurrent_safe!", error.message
  end

  def test_rejects_processing_after_shutdown
    pool = CDC::Concurrent::ProcessorPool.new(processor: SafeConcurrentProcessor.new, concurrency: 1)
    pool.shutdown

    assert_raises(CDC::Concurrent::ShutdownError) { pool.process(change_event) }
  end

  def test_rejects_process_many_after_shutdown
    pool = CDC::Concurrent::ProcessorPool.new(processor: SafeConcurrentProcessor.new, concurrency: 1)
    pool.shutdown

    assert_raises(CDC::Concurrent::ShutdownError) { pool.process_many([change_event]) }
  end

  def test_process_many_accepts_empty_batch
    pool = CDC::Concurrent::ProcessorPool.new(processor: SafeConcurrentProcessor.new, concurrency: 1)
    results = pool.process_many([])

    assert_empty results
    assert_predicate results, :frozen?
  ensure
    pool&.shutdown
  end

  def test_wraps_processor_error
    pool = CDC::Concurrent::ProcessorPool.new(processor: FailingConcurrentProcessor.new, concurrency: 1)
    result = pool.process(change_event)

    assert result.failure?
    assert_instance_of RuntimeError, result.error
  ensure
    pool&.shutdown
  end

  def test_returns_timeout_failure
    pool = CDC::Concurrent::ProcessorPool.new(
      processor: SlowConcurrentProcessor.new,
      concurrency: 1,
      timeout: 0.001
    )

    result = pool.process(change_event)

    assert result.failure?
    assert_instance_of CDC::Concurrent::TimeoutError, result.error
  ensure
    pool&.shutdown
  end

  def test_process_many_can_skip_order_preservation
    pool = CDC::Concurrent::ProcessorPool.new(
      processor: SafeConcurrentProcessor.new,
      concurrency: 2,
      preserve_order: false
    )

    results = pool.process_many([change_event(table: "users"), change_event(table: "orders")])

    assert_equal 2, results.length
    assert(results.all?(&:success?))
  ensure
    pool&.shutdown
  end

  def test_shutdown_is_idempotent
    pool = CDC::Concurrent::ProcessorPool.new(processor: SafeConcurrentProcessor.new, concurrency: 1)

    pool.shutdown
    pool.shutdown

    assert_raises(CDC::Concurrent::ShutdownError) { pool.process(change_event) }
  end
end
