# frozen_string_literal: true

module CDC
  module Concurrent
    # Executes one concurrent-safe processor using Async tasks.
    #
    # ARCHITECTURAL NOTE
    #
    # cdc-concurrent implements the same fan-out / fan-in execution pattern used
    # by cdc-parallel. The runtime differs, but the processor contract and result
    # contract remain the same.
    #
    #   events
    #      |
    #      v
    #   fan-out
    #      |
    #      +----> Async task
    #      +----> Async task
    #      +----> Async task
    #      |
    #      v
    #   fan-in
    #      |
    #      v
    #   ProcessorResult array
    #
    # Fan-out:
    #
    # * Events are dispatched into Async tasks.
    # * Async::Semaphore bounds the number of concurrently running tasks.
    # * Multiple events may make progress concurrently under Ruby's scheduler.
    #
    # Fan-in:
    #
    # * Tasks append indexed ProcessorResult values into a shared collection.
    # * Results may complete out of execution order.
    # * When preserve_order is enabled, ProcessorPool sorts by submission index so
    #   the returned array matches the input order.
    #
    # Relationship to cdc-parallel:
    #
    # * cdc-concurrent performs fan-out using Async tasks and cooperative
    #   concurrency.
    # * cdc-parallel performs fan-out using pre-warmed Ractor workers and true
    #   parallel execution.
    # * Both runtimes preserve the same processor contract and return
    #   CDC::Core::ProcessorResult objects.
    #
    # Processor authors should be able to switch runtimes without changing
    # processor behavior when their processor satisfies the selected runtime's
    # safety declaration.
    class ProcessorPool
      # Builds an Async-backed processor pool.
      #
      # @param processor [CDC::Core::Processor] Processor instance that declares concurrent_safe!.
      # @param concurrency [Integer] Maximum number of Async tasks allowed to run at once.
      # @param timeout [Float, nil] Optional per-event processing timeout in seconds.
      # @param preserve_order [Boolean] Whether process_many should return results in input order.
      # @raise [UnsafeProcessorError] If the processor does not declare concurrent_safe!.
      # @return [void] Does not return a useful value.
      def initialize(processor:, concurrency: 100, timeout: nil, preserve_order: true)
        validate_processor!(processor)

        @processor = processor
        @configuration = Configuration.new(concurrency:, timeout:, preserve_order:)
        @shutdown = false
      end

      # Processes one event synchronously through the Async runtime.
      #
      # @param event [CDC::Core::ChangeEvent] Event to process.
      # @raise [ShutdownError] If the pool has already been shut down.
      # @return [CDC::Core::ProcessorResult] Normalized processor result.
      def process(event)
        raise ShutdownError, "processor pool has been shut down" if @shutdown

        process_one(event)
      end

      # Processes many events through bounded Async fan-out.
      #
      # When preserve_order is true, the returned array matches the order of the
      # supplied events even if individual tasks complete out of order.
      #
      # @param events [Array<CDC::Core::ChangeEvent>] Events to process.
      # @raise [ShutdownError] If the pool has already been shut down.
      # @return [Array<CDC::Core::ProcessorResult>] Frozen array of normalized results.
      def process_many(events)
        raise ShutdownError, "processor pool has been shut down" if @shutdown
        return empty_results if events.empty?

        # @type var indexed_results: Array[[Integer, CDC::Core::ProcessorResult]]
        indexed_results = []

        process_batch(events, indexed_results)

        indexed_results.sort_by!(&:first) if @configuration.preserve_order
        indexed_results.map(&:last).freeze
      end

      # Prevents new work from being submitted to the pool.
      #
      # @return [void] Does not return a useful value.
      def shutdown
        @shutdown = true
      end

      private

      def validate_processor!(processor)
        return if processor.respond_to?(:concurrent_safe?) && processor.concurrent_safe?

        raise UnsafeProcessorError, "#{processor.class} must declare concurrent_safe!"
      end

      def empty_results
        # @type var results: Array[CDC::Core::ProcessorResult]
        results = []
        results.freeze
      end

      def process_batch(events, indexed_results)
        Async do |task|
          semaphore = Async::Semaphore.new(@configuration.concurrency, parent: task)

          events.each_with_index do |event, index|
            semaphore.async do |subtask|
              indexed_results << [index, process_with_task(subtask, event)]
            end
          end
        end.wait
      end

      def process_one(event)
        result = nil

        Async do |task|
          result = process_with_task(task, event)
        end.wait

        result
      rescue StandardError => e
        ResultCollector.failure(e)
      end

      def process_with_task(task, event)
        ResultCollector.normalize(call_processor(task, event))
      rescue Async::TimeoutError => e
        ResultCollector.failure(TimeoutError.new(e.message))
      rescue StandardError => e
        ResultCollector.failure(e)
      end

      def call_processor(task, event)
        return @processor.process(event) unless @configuration.timeout

        task.with_timeout(@configuration.timeout) { @processor.process(event) }
      end
    end
  end
end
