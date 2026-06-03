# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../../lib/cdc_concurrent"

class LoaderTest < Minitest::Test
  def test_top_level_loader_exposes_version
    assert_match(/\A\d+\.\d+\.\d+\z/, CDC::Concurrent::VERSION)
  end
end
