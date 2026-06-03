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

## License

MIT.
