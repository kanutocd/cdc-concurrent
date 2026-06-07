# frozen_string_literal: true

require "bundler/gem_tasks"
require "rubocop/rake_task"
require "yard"

TEST_GROUPS = {
  unit: "test/unit/**/*_test.rb",
  integration: "test/integration/**/*_test.rb",
  behavior: "test/behavior/**/*_test.rb",
  performance: "test/performance/**/*_test.rb"
}.freeze

DEFAULT_TEST_GROUPS = %i[unit integration behavior].freeze

def run_test_files(pattern)
  test_files = Dir[pattern]
  abort "No test files matched #{pattern}" if test_files.empty?

  sh test_command(test_files)
end

def test_command(test_files)
  requires = test_requires(test_files)

  [
    RbConfig.ruby,
    "-r./test/coverage_helper",
    "-Ilib:test",
    "-w",
    "-e",
    requires.inspect
  ].join(" ")
end

def test_requires(test_files)
  test_files.map { |file| "require_relative #{file.inspect}" }.join("; ")
end

RuboCop::RakeTask.new(:rubocop) { |task| task.options = ["--parallel"] }

YARD::Rake::YardocTask.new(:yard) do |task|
  task.files = ["lib/**/*.rb"]
  task.options = ["--protected"]
end

task default: %i[test rubocop yard]

desc "Run unit, integration, and behavior tests"
task :test do
  ENV["COVERAGE"] = "true"
  ENV["TEST_GROUP"] = "all"
  run_test_files("test/{unit,integration,behavior}/**/*_test.rb")
end

namespace :test do
  TEST_GROUPS.each do |name, pattern|
    desc "Run #{name} tests"
    task name do
      ENV["TEST_GROUP"] = name.to_s
      run_test_files(pattern)
    end
  end

  desc "Run all test groups, including performance tests"
  task all: TEST_GROUPS.keys.map { |group| "test:#{group}" }
end

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
