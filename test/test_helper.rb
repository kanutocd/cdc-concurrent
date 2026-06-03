# frozen_string_literal: true

require "simplecov"

SimpleCov.command_name "Minitest"
SimpleCov.use_merging false
SimpleCov.at_exit do
  nil
end

SimpleCov.start do
  enable_coverage :branch
  minimum_coverage line: 95, branch: 100
  add_filter "/test/"
  track_files "lib/**/*.rb"
end

require "minitest/autorun"
require_relative "../lib/cdc/concurrent"

Minitest.after_run do
  SimpleCov.result.format!
end
