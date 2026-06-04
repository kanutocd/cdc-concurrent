ARG RUBY_IMAGE=ruby:3.4-slim
FROM ${RUBY_IMAGE}

RUN apt-get update \
  && apt-get install -y --no-install-recommends build-essential ca-certificates git \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY Gemfile cdc-concurrent.gemspec ./
COPY README.md CHANGELOG.md LICENSE.txt ./
COPY lib ./lib
COPY sig ./sig
COPY benchmark ./benchmark

RUN bundle install

ENV BENCHMARK_WORKLOAD=io \
    BENCHMARK_ITERATIONS=1000 \
    BENCHMARK_WARMUP=100 \
    BENCHMARK_CONCURRENCY_COUNTS=1,10,50,100

CMD ["bundle", "exec", "ruby", "benchmark/processor_pool_benchmark.rb"]
