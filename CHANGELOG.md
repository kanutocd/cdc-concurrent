## [0.1.0] - 2026-06-04

  Initial release of `cdc-concurrent`.

  ### Added

  - Async-backed I/O-concurrent runtime adapter for `cdc-core`.
  - `CDC::Concurrent::Runtime` for processing single events, batches, and transaction envelopes.
  - `CDC::Concurrent::ProcessorPool` for concurrent `ChangeEvent` processing.
  - `CDC::Concurrent::TransactionPool` for transaction envelope processing.
  - `CDC::Concurrent::Router` for routing supported CDC work items.
  - `concurrent_safe!` processor declaration.
  - Timeout handling with `CDC::Concurrent::TimeoutError`.
  - Shutdown and unsupported work item errors.
  - Result normalization to `CDC::Core::ProcessorResult`.
  - Unit, integration, behavior, and performance test groups.
  - RBS signatures.
  - README positioning `cdc-concurrent` as the I/O-bound sibling of `cdc-parallel`.

  ### Notes

  - Requires Ruby 3.4+.
  - Designed for I/O-bound processors that cooperate with Ruby's Fiber scheduler.
  - CPU-bound CDC processing should use `cdc-parallel`.
