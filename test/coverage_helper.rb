# frozen_string_literal: true

return unless ENV.fetch("COVERAGE", "false") == "true"

require "simplecov"

SimpleCov.command_name ENV.fetch("TEST_GROUP", "Minitest")
SimpleCov.use_merging false

SimpleCov.start do
  enable_coverage :branch
  minimum_coverage line: 95, branch: 100
  add_filter "/test/"
  track_files "lib/**/*.rb"
end
