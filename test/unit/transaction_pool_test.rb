# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../support/processors"
require_relative "../support/events"

class TransactionPoolTest < Minitest::Test
  include EventFixtures

  def test_processes_all_transaction_events_successfully
    pool = CDC::Concurrent::TransactionPool.new(processor: SafeConcurrentProcessor.new, concurrency: 2)

    result = pool.process(transaction_with_tables("users", "orders"))

    assert result.success?
    assert_equal 2, result.event.length
    assert(result.event.all?(&:success?))
  ensure
    pool&.shutdown
  end

  def test_transaction_fails_when_any_event_fails
    pool = CDC::Concurrent::TransactionPool.new(processor: FlakyConcurrentProcessor.new, concurrency: 2)

    result = pool.process(transaction_with_tables("users", "failures", "orders"))

    assert result.failure?
    assert_equal 3, result.event.length
    assert_equal [false, true, false], result.event.map(&:failure?)
    assert_instance_of RuntimeError, result.error
  ensure
    pool&.shutdown
  end
end
