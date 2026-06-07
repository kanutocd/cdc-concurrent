# cdc-concurrent Benchmarking

This directory contains the reproducible benchmark harness for `cdc-concurrent`.

The benchmark compares direct serial processor execution against the
Async-backed `CDC::Concurrent::ProcessorPool`.

## Goals

The benchmark is designed to answer practical runtime questions:

- What is the dispatch overhead for tiny work?
- When does Async-backed I/O concurrency amortize its overhead?
- How much does batched `process_many` improve throughput?
- How does throughput change as concurrency changes?
- Are results stable across multiple trials?

## Workloads

| Workload | Purpose                                      | Default options          |
| -------- | -------------------------------------------- | ------------------------ |
| tiny     | Measures processor-pool dispatch cost        | none                     |
| io       | Measures scheduler-friendly I/O wait overlap | `io_sleep: 0.001`        |
| batch    | Measures CDC-style batch I/O fanout          | `batch_size: 100`, `io_sleep: 0.001` |

Tiny workloads intentionally do almost no work. They are useful for measuring
runtime overhead, but they are not expected to make concurrent execution look
faster than direct method calls.

I/O and batch workloads are better indicators of useful concurrent throughput.

## Execution Modes

The benchmark compares three execution modes.

| Mode             | Meaning                                      |
| ---------------- | -------------------------------------------- |
| serial           | Direct processor execution                   |
| repeated_process | Repeated `ProcessorPool#process` calls       |
| process_many     | Batched `ProcessorPool#process_many` calls   |

`serial` is measured once per benchmark run. `repeated_process` and
`process_many` are measured once for each configured concurrency count.

For `cdc-concurrent`, `process_many` is the primary throughput path. Repeated
single-event `process` calls are included to expose per-dispatch overhead, but
they do not represent the best way to overlap I/O waits.

## Configuration

| Environment variable             | Default | Meaning                                      |
| -------------------------------- | ------- | -------------------------------------------- |
| `BENCHMARK_WORKLOAD`             | `io`    | `tiny`, `io`, or `batch`                     |
| `BENCHMARK_ITERATIONS`           | `1000`  | Work items submitted per pass                |
| `BENCHMARK_WARMUP`               | `100`   | Warmup work items before measurement         |
| `BENCHMARK_TRIALS`               | `5`     | Number of measured trials                    |
| `BENCHMARK_MIN_DURATION`         | `0.1`   | Minimum seconds per trial                    |
| `BENCHMARK_CONCURRENCY`          | `100`   | Single concurrency count when no sweep is given |
| `BENCHMARK_CONCURRENCY_COUNTS`   | unset   | Comma-separated concurrency sweep, e.g. `10,50,100` |
| `BENCHMARK_IO_SLEEP`             | `0.001` | Seconds slept by I/O-like workloads          |
| `BENCHMARK_BATCH_SIZE`           | `100`   | Events inside each batch workload item       |

`BENCHMARK_CONCURRENCY_COUNTS` takes precedence over `BENCHMARK_CONCURRENCY`.

## Examples

Run the default I/O workload:

```bash
bundle exec rake benchmark:processor_pool
```

Run the tiny overhead workload:

```bash
BENCHMARK_WORKLOAD=tiny \
bundle exec rake benchmark:processor_pool
```

Run the I/O workload with a custom concurrency sweep:

```bash
BENCHMARK_WORKLOAD=io \
BENCHMARK_CONCURRENCY_COUNTS=10,50,100 \
bundle exec rake benchmark:processor_pool
```

Run a longer batch benchmark:

```bash
BENCHMARK_WORKLOAD=batch \
BENCHMARK_TRIALS=9 \
BENCHMARK_MIN_DURATION=0.5 \
BENCHMARK_CONCURRENCY_COUNTS=10,50,100 \
bundle exec rake benchmark:processor_pool
```

Build and run the reusable Docker benchmark image:

```bash
bundle exec rake benchmark:docker_build
bundle exec rake benchmark:docker_run
```

## Report Shape

The benchmark prints JSON.

Top-level fields:

| Field               | Meaning                                      |
| ------------------- | -------------------------------------------- |
| `benchmark`         | Benchmark name                               |
| `gem`               | Gem name                                     |
| `timestamp`         | UTC timestamp                                |
| `environment`       | Ruby, platform, host, CPU, and uname metadata |
| `config`            | Benchmark configuration                      |
| `workload_options`  | Workload-specific options                    |
| `serial`            | Serial execution distribution                |
| `concurrency_sweep` | Concurrent mode distributions by concurrency |
| `interpretation`    | Ratio interpretation guide                   |

Each distribution includes:

| Field    | Meaning                          |
| -------- | -------------------------------- |
| `min`    | Fastest observed value           |
| `median` | Median observed value            |
| `max`    | Slowest observed value           |
| `p95`    | 95th percentile observed value   |

Each mode also includes `raw_trials` so results can be inspected or reprocessed.

## Interpretation

`ratio_to_serial_median_events_per_second` compares a concurrent mode's median
throughput against serial median throughput.

```text
ratio_to_serial_median_events_per_second > 1.0  => concurrent mode faster
ratio_to_serial_median_events_per_second = 1.0  => equivalent
ratio_to_serial_median_events_per_second < 1.0  => serial faster
```

Tiny workloads primarily measure dispatch overhead, so serial execution may be
faster. I/O-bound and batched workloads are better indicators of useful
concurrent throughput.

`cdc-parallel` and `cdc-concurrent` benchmark different bottlenecks.
`cdc-parallel` measures CPU parallelism; `cdc-concurrent` measures I/O wait
overlap. Their speedup ratios are not directly comparable.

## Reproducibility

Benchmark results vary depending on:

- CPU model
- operating system
- Ruby version
- background system activity
- scheduler-compatible I/O behavior
- thermal and power-management state

Use multiple trials, a minimum measurement duration, and concurrency sweeps when
comparing results across machines or releases.
