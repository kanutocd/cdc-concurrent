# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../support/processors"
require_relative "../support/events"

class RouterTest < Minitest::Test
  include EventFixtures

  def test_rejects_unknown_item
    processor = SafeConcurrentProcessor.new
    processor_pool = CDC::Concurrent::ProcessorPool.new(processor:, concurrency: 1)
    transaction_pool = CDC::Concurrent::TransactionPool.new(processor:, concurrency: 1)
    router = CDC::Concurrent::Router.new(processor_pool:, transaction_pool:)

    assert_raises(CDC::Concurrent::UnsupportedWorkItemError) { router.process(Object.new) }
  ensure
    processor_pool&.shutdown
    transaction_pool&.shutdown
  end
end
