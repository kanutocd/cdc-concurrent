## [0.1.1] - 2026-06-12

  Tightened the type surface and switched the signatures over to the published
  `cdc-core` 0.1.3 RBS files.

  ### Added

  - Published `cdc-core` RBS files are now loaded directly by Steep.
  - `CDC::Concurrent` signatures are tighter around runtime, router, and pool
    boundaries.

  ### Changed

  - Removed local RBS shims for `cdc-core` and `async`.
  - Updated the gem dependency floor to `cdc-core >= 0.1.3`.

  ### Fixed

  - `TransactionPool` now handles failure results with a missing error value
    defensively.

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
