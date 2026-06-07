# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../support/processors"
require_relative "../support/events"

class ProcessorPoolIntegrationTest < Minitest::Test
  include EventFixtures

  def test_processes_event
    pool = CDC::Concurrent::ProcessorPool.new(processor: SafeConcurrentProcessor.new, concurrency: 1)

    result = pool.process(change_event)

    assert_predicate result, :success?
    assert_equal :update, result.event[:operation]
  ensure
    pool&.shutdown
  end

  def test_preserves_order_for_many_events
    pool = CDC::Concurrent::ProcessorPool.new(processor: SafeConcurrentProcessor.new, concurrency: 4)

    results = pool.process_many(ordered_events)
    tables = results.map { |result| result.event[:table] }

    assert_equal %w[a b c], tables
    assert_predicate results, :frozen?
  ensure
    pool&.shutdown
  end

  private

  def ordered_events
    [change_event(table: "a"), change_event(table: "b"), change_event(table: "c")]
  end
end
