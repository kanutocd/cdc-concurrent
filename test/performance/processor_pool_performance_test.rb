# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../support/processors"
require_relative "../support/events"

class ProcessorPoolPerformanceTest < Minitest::Test
  include EventFixtures

  def test_process_many_is_faster_than_repeated_process_for_io_bound_work
    events = slow_events
    sequential_elapsed = elapsed_time { process_sequentially(events) }
    concurrent_elapsed = elapsed_time { process_concurrently(events) }

    assert_operator concurrent_elapsed, :<, sequential_elapsed
  end

  def test_process_many_completes_within_smoke_threshold
    pool = CDC::Concurrent::ProcessorPool.new(processor: SlowConcurrentProcessor.new, concurrency: 3)
    events = Array.new(3) { |index| change_event(table: "table_#{index}") }

    elapsed = elapsed_time do
      results = pool.process_many(events)
      assert(results.all?(&:success?))
    end

    assert_operator elapsed, :<, 0.12
  ensure
    pool&.shutdown
  end

  private

  def slow_events
    Array.new(3) { |index| change_event(table: "table_#{index}") }
  end

  def process_sequentially(events)
    pool = CDC::Concurrent::ProcessorPool.new(processor: SlowConcurrentProcessor.new, concurrency: 1)
    events.each { |event| pool.process(event) }
  ensure
    pool&.shutdown
  end

  def process_concurrently(events)
    pool = CDC::Concurrent::ProcessorPool.new(processor: SlowConcurrentProcessor.new, concurrency: 3)
    results = pool.process_many(events)

    assert(results.all?(&:success?))
  ensure
    pool&.shutdown
  end

  def elapsed_time
    started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    yield
    Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at
  end
end
