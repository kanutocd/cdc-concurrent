# frozen_string_literal: true

require_relative "../test_helper"

class ResultCollectorTest < Minitest::Test
  def test_normalize_returns_processor_result_unchanged
    original = CDC::Core::ProcessorResult.success(:ok)

    assert_same original, CDC::Concurrent::ResultCollector.normalize(original)
  end

  def test_normalize_wraps_raw_value_as_success_event
    result = CDC::Concurrent::ResultCollector.normalize(:ok)

    assert result.success?
    assert_equal :ok, result.event
  end

  def test_normalize_wraps_normalization_error_as_failure
    CDC::Core::ProcessorResult.stub(:success, ->(_value) { raise "bad result" }) do
      result = CDC::Concurrent::ResultCollector.normalize(:ok)

      assert result.failure?
      assert_instance_of RuntimeError, result.error
      assert_equal "bad result", result.error.message
    end
  end

  def test_failure_wraps_error
    error = RuntimeError.new("boom")
    result = CDC::Concurrent::ResultCollector.failure(error)

    assert result.failure?
    assert_same error, result.error
  end
end
