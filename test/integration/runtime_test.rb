# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../support/processors"
require_relative "../support/events"

class RuntimeTest < Minitest::Test
  include EventFixtures

  def test_processes_change_event
    runtime = CDC::Concurrent::Runtime.new(processor: SafeConcurrentProcessor.new, concurrency: 2)

    result = runtime.process(change_event)

    assert result.success?
    assert_equal "users", result.event[:table]
  ensure
    runtime&.shutdown
  end

  def test_processes_many_events
    runtime = CDC::Concurrent::Runtime.new(processor: SafeConcurrentProcessor.new, concurrency: 2)

    results = runtime.process_many([change_event(table: "users"), change_event(table: "posts")])
    tables = results.map { |result| result.event[:table] }

    assert_equal 2, results.length
    assert_equal %w[users posts], tables
  ensure
    runtime&.shutdown
  end

  def test_processes_transaction_envelope
    runtime = CDC::Concurrent::Runtime.new(processor: SafeConcurrentProcessor.new, concurrency: 2)

    result = runtime.process_transaction(transaction)

    assert result.success?
    assert_equal 1, result.event.length
  ensure
    runtime&.shutdown
  end

  def test_rejects_unsafe_processor
    assert_raises(CDC::Concurrent::UnsafeProcessorError) do
      CDC::Concurrent::Runtime.new(processor: UnsafeConcurrentProcessor.new, concurrency: 1)
    end
  end

  def test_rejects_processing_after_shutdown
    runtime = CDC::Concurrent::Runtime.new(processor: SafeConcurrentProcessor.new, concurrency: 1)
    runtime.shutdown

    assert_raises(CDC::Concurrent::ShutdownError) { runtime.process(change_event) }
  end

  def test_shutdown_is_idempotent
    runtime = CDC::Concurrent::Runtime.new(processor: SafeConcurrentProcessor.new, concurrency: 1)

    runtime.shutdown
    runtime.shutdown

    assert_raises(CDC::Concurrent::ShutdownError) { runtime.process(change_event) }
  end
end
