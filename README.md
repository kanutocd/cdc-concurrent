# cdc-concurrent

Optional I/O-concurrent runtime adapter for `cdc-core`.

`cdc-concurrent` executes `CDC::Core::Processor` objects with Fiber-scheduler-based I/O concurrency using `async`. It is the I/O-bound twin of `cdc-parallel`.

## Requirements

- Ruby 3.4+
- `cdc-core`
- `async`

## Purpose

```text
cdc-core
   |
   |-- cdc-parallel
   |      CPU-bound parallelism
   |
   `-- cdc-concurrent
          I/O-bound concurrency
```

Use `cdc-concurrent` for processors that spend most of their time waiting on fiber-scheduler-compatible I/O:

- HTTP webhooks
- external API enrichment
- Redis publishing
- OpenSearch or Elasticsearch indexing
- S3 or object-storage writes
- async sink fanout
- database writes through compatible drivers

Use `cdc-parallel` for CPU-bound work such as pgoutput parsing, OID decoding, JSON parsing, diff computation, compression, and analytics calculations.

## Installation

```ruby
gem "cdc-concurrent"
```

## Usage

```ruby
require "cdc/core"
require "cdc/concurrent"

class WebhookProcessor < CDC::Core::Processor
  concurrent_safe!

  def process(event)
    # Perform fiber-scheduler-compatible I/O here.
    CDC::Core::ProcessorResult.success(event)
  end
end

runtime = CDC::Concurrent::Runtime.new(
  processor: WebhookProcessor.new,
  concurrency: 100,
  timeout: 5.0
)

result = runtime.process(event)
runtime.shutdown
```

## Batch Processing

```ruby
results = runtime.process_many(events)
```

Results preserve input order by default. Set `preserve_order: false` when completion order is acceptable.

## Transaction Processing

```ruby
result = runtime.process_transaction(transaction)
```

Transactions are processed event-by-event. The returned `ProcessorResult#event` contains the per-event results. If any event fails, the transaction result fails and carries the first error.

## Processor Safety

Only processors that declare `concurrent_safe!` can run in this runtime.

```ruby
class SinkProcessor < CDC::Core::Processor
  concurrent_safe!
end
```

Unsafe processors raise:

```ruby
CDC::Concurrent::UnsafeProcessorError
```

A concurrent-safe processor should avoid unsafe shared mutable instance state. This runtime runs tasks concurrently in one Ruby process; it does not isolate mutable objects like Ractors do.

## Important Limits

`cdc-concurrent` improves throughput only for I/O that cooperates with Ruby's Fiber scheduler. Blocking libraries that do not yield to the scheduler will still block the process.

For CPU-bound processing, use `cdc-parallel`.

## Roadmap

- Move `concurrent_safe!` into `cdc-core`
- Retry and backoff policies
- Dead-letter handling
- Async HTTP webhook helpers
- Sink abstractions
- Async Redis/OpenSearch integrations

## Test Organization

The test suite is grouped by intent so the same structure can be reused across CDC ecosystem gems.

```text
test/unit/          focused class and branch coverage
test/integration/   component interaction and runtime integration
test/behavior/      ecosystem contracts and guardrails
test/performance/   opt-in smoke benchmarks
```

Run the default quality suite:

```bash
bundle exec rake test
```

Run a specific group:

```bash
bundle exec rake test:unit
bundle exec rake test:integration
bundle exec rake test:behavior
bundle exec rake test:performance
```

The default `test` task runs unit, integration, and behavior tests. Performance tests are intentionally separate because they are environment-sensitive.

## Benchmarking

`cdc-concurrent` includes reproducible benchmarks that compare serial processor execution against the Async-backed processor pool.

The benchmark focuses on three workload categories:

| Workload | Purpose                                      |
| -------- | -------------------------------------------- |
| tiny     | Measure dispatch overhead                    |
| io       | Measure scheduler-friendly I/O concurrency   |
| batch    | Measure batched CDC event I/O fanout         |

See [benchmark/README.md](benchmark/README.md) for the full benchmark methodology,
configuration reference, report schema, and interpretation guidance.

### Quick Start

Default I/O workload:

```bash
bundle exec rake benchmark:processor_pool
```

Tiny overhead workload:

```bash
BENCHMARK_WORKLOAD=tiny \
bundle exec rake benchmark:processor_pool
```

Batch workload:

```bash
BENCHMARK_WORKLOAD=batch \
BENCHMARK_BATCH_SIZE=1000 \
bundle exec rake benchmark:processor_pool
```

Concurrency sweep:

```bash
BENCHMARK_WORKLOAD=io \
BENCHMARK_CONCURRENCY_COUNTS=1,10,50,100 \
bundle exec rake benchmark:processor_pool
```

Credibility controls:

```bash
BENCHMARK_TRIALS=7 \
BENCHMARK_MIN_DURATION=0.25 \
BENCHMARK_ITERATIONS=1000 \
bundle exec rake benchmark:processor_pool
```

### Benchmark Docker Image

Build and run the reusable Docker image:

```bash
bundle exec rake benchmark:docker_build
bundle exec rake benchmark:docker_run
```

Or run the image directly after it is published to GitHub Container Registry:

```bash
docker run --rm ghcr.io/kanutocd/cdc-concurrent-benchmark:main
```

The benchmark image is intended to follow the shared performance validation
pattern across CDC Ecosystem gems, enabling reproducible benchmark execution
locally, in CI, and across different development environments.

## License

MIT.
