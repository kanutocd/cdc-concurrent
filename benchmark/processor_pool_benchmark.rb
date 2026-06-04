# frozen_string_literal: true

require "bundler/setup"
require "etc"
require "json"
require "socket"
require "time"
require "cdc_concurrent"
require "cdc/core"

# Reproducible processor-pool benchmark entrypoint.
module CDCConcurrentBenchmark # rubocop:disable Metrics/ModuleLength
  module_function

  Config = Data.define(
    :iterations,
    :warmup,
    :concurrency_counts,
    :trials,
    :min_duration,
    :workload,
    :batch_size,
    :io_sleep
  )
  Trial = Data.define(:elapsed, :passes, :effective_events)

  VALID_WORKLOADS = %w[tiny io batch].freeze

  def integer_env(name, default)
    value = ENV.fetch(name, default.to_s)
    Integer(value)
  rescue ArgumentError
    warn "#{name} must be an integer; got #{value.inspect}"
    exit 1
  end

  def positive_integer_env(name, default)
    value = integer_env(name, default)
    return value if value.positive?

    warn "#{name} must be greater than zero; got #{value.inspect}"
    exit 1
  end

  def nonnegative_integer_env(name, default)
    value = integer_env(name, default)
    return value if value >= 0

    warn "#{name} must be zero or greater; got #{value.inspect}"
    exit 1
  end

  def float_env(name, default)
    value = ENV.fetch(name, default.to_s)
    Float(value)
  rescue ArgumentError
    warn "#{name} must be numeric; got #{value.inspect}"
    exit 1
  end

  def positive_float_env(name, default)
    value = float_env(name, default)
    return value if value.positive?

    warn "#{name} must be greater than zero; got #{value.inspect}"
    exit 1
  end

  def nonnegative_float_env(name, default)
    value = float_env(name, default)
    return value if value >= 0

    warn "#{name} must be zero or greater; got #{value.inspect}"
    exit 1
  end

  def concurrency_counts_env
    value = ENV.fetch("BENCHMARK_CONCURRENCY_COUNTS", nil)
    return [positive_integer_env("BENCHMARK_CONCURRENCY", 100)] unless value

    counts = value.split(",").map { |entry| Integer(entry.strip) }
    return counts if counts.any? && counts.all?(&:positive?)

    warn "BENCHMARK_CONCURRENCY_COUNTS must contain positive integers; got #{value.inspect}"
    exit 1
  rescue ArgumentError
    warn "BENCHMARK_CONCURRENCY_COUNTS must be a comma-separated integer list; got #{value.inspect}"
    exit 1
  end

  def workload_env
    workload = ENV.fetch("BENCHMARK_WORKLOAD", "io")

    return workload if VALID_WORKLOADS.include?(workload)

    warn "BENCHMARK_WORKLOAD must be one of #{VALID_WORKLOADS.join(", ")}; got #{workload.inspect}"
    exit 1
  end

  def monotonic
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end

  def config
    Config.new(
      iterations: positive_integer_env("BENCHMARK_ITERATIONS", 1_000),
      warmup: nonnegative_integer_env("BENCHMARK_WARMUP", 100),
      concurrency_counts: concurrency_counts_env,
      trials: positive_integer_env("BENCHMARK_TRIALS", 5),
      min_duration: positive_float_env("BENCHMARK_MIN_DURATION", 0.1),
      workload: workload_env,
      batch_size: positive_integer_env("BENCHMARK_BATCH_SIZE", 100),
      io_sleep: nonnegative_float_env("BENCHMARK_IO_SLEEP", 0.001)
    )
  end

  def change_event(counter)
    CDC::Core::ChangeEvent.new(
      operation: :update,
      schema: "public",
      table: "benchmark_events",
      old_values: { "counter" => counter - 1 },
      new_values: { "counter" => counter },
      transaction_id: counter
    )
  end

  def event
    change_event(42)
  end

  def batch_event(settings)
    Array.new(settings.batch_size) { |index| change_event(index + 1) }
  end

  # Minimal concurrent-safe processor.
  #
  # This intentionally benchmarks the overhead of the processor pool itself.
  class TinyProcessor < CDC::Core::Processor
    concurrent_safe!

    def process(event)
      payload = {
        operation: event.operation,
        schema: event.schema,
        table: event.table,
        changed: event.new_values.keys
      }

      CDC::Core::ProcessorResult.success(payload)
    end
  end

  # I/O-like processor.
  #
  # The sleep call cooperates with Async's fiber scheduler inside the pool.
  class IoProcessor < CDC::Core::Processor
    concurrent_safe!

    def initialize(sleep_seconds:)
      @sleep_seconds = sleep_seconds
      super()
    end

    def process(event)
      sleep @sleep_seconds

      CDC::Core::ProcessorResult.success(
        {
          operation: event.operation,
          table: event.table,
          waited_seconds: @sleep_seconds
        }
      )
    end
  end

  # Batch I/O-like processor.
  #
  # This models one runtime dispatch that fans out over a group of CDC events.
  class BatchIoProcessor < CDC::Core::Processor
    concurrent_safe!

    def initialize(sleep_seconds:)
      @sleep_seconds = sleep_seconds
      super()
    end

    def process(events)
      sleep @sleep_seconds

      CDC::Core::ProcessorResult.success(
        {
          count: events.length,
          tables: events.map(&:table).uniq,
          waited_seconds: @sleep_seconds
        }
      )
    end
  end

  def processor_for(settings)
    case settings.workload
    when "tiny"
      TinyProcessor.new
    when "io"
      IoProcessor.new(sleep_seconds: settings.io_sleep)
    when "batch"
      BatchIoProcessor.new(sleep_seconds: settings.io_sleep)
    else
      raise "unsupported workload: #{settings.workload}"
    end
  end

  def sample_event_for(settings)
    settings.workload == "batch" ? batch_event(settings) : event
  end

  def effective_events_per_pass(settings)
    settings.workload == "batch" ? settings.iterations * settings.batch_size : settings.iterations
  end

  def run_trial(settings)
    passes = 0
    started_at = monotonic

    loop do
      yield
      passes += 1
      break if monotonic - started_at >= settings.min_duration
    end

    trial_for(settings, passes, monotonic - started_at)
  end

  def trial_for(settings, passes, elapsed)
    Trial.new(
      elapsed: elapsed,
      passes: passes,
      effective_events: passes * effective_events_per_pass(settings)
    )
  end

  def run_trials(settings, &)
    Array.new(settings.trials) { run_trial(settings, &) }
  end

  def serial_trials(settings, sample_event)
    processor = processor_for(settings)
    settings.warmup.times { processor.process(sample_event) }

    run_trials(settings) do
      settings.iterations.times do
        result = processor.process(sample_event)
        raise "serial processor failed" unless result.success?
      end
    end
  end

  def repeated_process_trials(settings, sample_event, concurrency)
    with_pool(settings, concurrency) do |pool|
      settings.warmup.times { pool.process(sample_event) }

      run_trials(settings) do
        settings.iterations.times do
          result = pool.process(sample_event)
          raise "pool.process failed" unless result.success?
        end
      end
    end
  end

  def process_many_trials(settings, sample_event, concurrency)
    with_pool(settings, concurrency) do |pool|
      warmup_items = Array.new(settings.warmup) { sample_event }
      benchmark_items = Array.new(settings.iterations) { sample_event }

      pool.process_many(warmup_items)
      run_trials(settings) do
        results = pool.process_many(benchmark_items)
        raise "pool.process_many failed" unless results.all?(&:success?)
      end
    end
  end

  def with_pool(settings, concurrency)
    pool = CDC::Concurrent::ProcessorPool.new(
      processor: processor_for(settings),
      concurrency: concurrency
    )

    yield pool
  ensure
    pool&.shutdown
  end

  def report(settings, serial)
    {
      benchmark: "processor_pool",
      gem: "cdc-concurrent",
      timestamp: Time.now.utc.iso8601,
      **report_body(settings, serial)
    }
  end

  def report_body(settings, serial)
    {
      environment: environment,
      config: config_report(settings),
      workload_options: workload_options(settings),
      serial: summarize_trials(serial),
      concurrency_sweep: concurrency_sweep(settings, serial),
      interpretation: interpretation
    }
  end

  def config_report(settings)
    {
      iterations: settings.iterations,
      warmup: settings.warmup,
      trials: settings.trials,
      min_duration_seconds: settings.min_duration,
      concurrency_counts: settings.concurrency_counts,
      workload: settings.workload
    }
  end

  def environment
    {
      ruby: RUBY_DESCRIPTION,
      ruby_engine: defined?(RUBY_ENGINE) ? RUBY_ENGINE : "ruby",
      ruby_engine_version: defined?(RUBY_ENGINE_VERSION) ? RUBY_ENGINE_VERSION : RUBY_VERSION,
      platform: RUBY_PLATFORM,
      hostname: Socket.gethostname,
      cpu_count: Etc.nprocessors,
      uname: Etc.respond_to?(:uname) ? Etc.uname : {}
    }
  end

  def workload_options(settings)
    case settings.workload
    when "tiny"
      {}
    when "io"
      { io_sleep_seconds: settings.io_sleep }
    when "batch"
      { batch_size: settings.batch_size, io_sleep_seconds: settings.io_sleep }
    end
  end

  def concurrency_sweep(settings, serial)
    sample_event = sample_event_for(settings)

    settings.concurrency_counts.map do |concurrency|
      repeated = repeated_process_trials(settings, sample_event, concurrency)
      many = process_many_trials(settings, sample_event, concurrency)

      concurrency_report(concurrency, serial, repeated, many)
    end
  end

  def concurrency_report(concurrency, serial, repeated, many)
    {
      concurrency: concurrency,
      repeated_process: concurrent_summary(serial, repeated),
      process_many: concurrent_summary(serial, many)
    }
  end

  def concurrent_summary(serial, trials)
    throughput_ratio = ratio(
      serial_value: median(throughputs(serial)),
      concurrent_value: median(throughputs(trials))
    )
    summary = summarize_trials(trials)

    summary.merge(
      ratio_to_serial_median_events_per_second: throughput_ratio,
      interpretation: interpretation_for(throughput_ratio)
    )
  end

  def summarize_trials(trials)
    elapsed = trials.map(&:elapsed)
    throughput = throughputs(trials)

    {
      trials: trials.length,
      elapsed_seconds: distribution(elapsed),
      events_per_second: distribution(throughput),
      effective_events: distribution(trials.map(&:effective_events)),
      passes: distribution(trials.map(&:passes)),
      raw_trials: trials.map { |trial| trial_report(trial) }
    }
  end

  def trial_report(trial)
    {
      elapsed_seconds: trial.elapsed.round(6),
      effective_events: trial.effective_events,
      passes: trial.passes,
      events_per_second: (trial.effective_events / trial.elapsed).round(2)
    }
  end

  def distribution(values)
    sorted = values.sort

    {
      min: format_stat(sorted.first),
      median: format_stat(median(sorted)),
      max: format_stat(sorted.last),
      p95: format_stat(percentile(sorted, 95))
    }
  end

  def median(values)
    sorted = values.sort
    mid = sorted.length / 2

    return sorted[mid] if sorted.length.odd?

    (sorted[mid - 1] + sorted[mid]) / 2.0
  end

  def percentile(sorted_values, percentile)
    index = ((percentile / 100.0) * (sorted_values.length - 1)).ceil
    sorted_values[index]
  end

  def format_stat(value)
    value.is_a?(Integer) ? value : value.round(6)
  end

  def throughputs(trials)
    trials.map { |trial| trial.effective_events / trial.elapsed }
  end

  def ratio(serial_value:, concurrent_value:)
    (concurrent_value / serial_value).round(4)
  end

  def interpretation_for(value)
    if value > 1
      "concurrent faster"
    elsif value == 1
      "concurrent equal to serial"
    else
      "serial faster"
    end
  end

  def interpretation
    {
      "ratio > 1.0" => "concurrent median throughput is higher",
      "ratio = 1.0" => "concurrent and serial median throughput are equivalent",
      "ratio < 1.0" => "serial median throughput is higher"
    }
  end

  def run
    settings = config
    sample_event = sample_event_for(settings)
    serial = serial_trials(settings, sample_event)

    puts JSON.pretty_generate(report(settings, serial))
  end
end

CDCConcurrentBenchmark.run
