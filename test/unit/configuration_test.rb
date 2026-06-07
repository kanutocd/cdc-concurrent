# frozen_string_literal: true

require_relative "../test_helper"

class ConfigurationTest < Minitest::Test
  def test_accepts_valid_configuration
    config = CDC::Concurrent::Configuration.new(concurrency: 10, timeout: 1.0, preserve_order: false)

    assert_equal 10, config.concurrency
    assert_in_delta(1.0, config.timeout)
    refute config.preserve_order
  end

  def test_rejects_invalid_concurrency
    assert_raises(ArgumentError) { CDC::Concurrent::Configuration.new(concurrency: 0) }
    assert_raises(ArgumentError) { CDC::Concurrent::Configuration.new(concurrency: "x") }
  end
end
