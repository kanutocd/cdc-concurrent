# frozen_string_literal: true

require "bundler/gem_tasks"
require "minitest/test_task"
require "rubocop/rake_task"
require "yard"

Minitest::TestTask.create(:test) do |task|
  task.libs << "test"
  task.warning = true
  task.test_globs = ["test/**/*_test.rb"]
end

RuboCop::RakeTask.new(:rubocop) { |task| task.options = ["--parallel"] }

YARD::Rake::YardocTask.new(:yard) do |task|
  task.files = ["lib/**/*.rb"]
  task.options = ["--protected"]
end

task default: %i[test rubocop yard]

namespace :rbs do
  desc "Remove all non-shimmed sig files"
  task :clean do
    sh "rm -rf ./sig/cdc_concurrent.rbs ./sig/cdc"
  end

  desc "Generate RBS signatures"
  task :generate do
    sh "bundle exec rbs prototype rb --out-dir=sig --base-dir=lib lib"
  end

  desc "Validate RBS signatures"
  task :validate do
    sh "bundle exec steep check"
  end
end

namespace :benchmark do
  desc "Run the processor pool benchmark locally"
  task :processor_pool do
    sh "bundle exec ruby benchmark/processor_pool_benchmark.rb"
  end

  desc "Build the reusable benchmark Docker image"
  task :docker_build do
    sh "docker build -f docker/benchmark/Dockerfile -t cdc-concurrent-benchmark ."
  end

  desc "Run the benchmark Docker image"
  task :docker_run do
    sh "docker run --rm cdc-concurrent-benchmark"
  end
end
