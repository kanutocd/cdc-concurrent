# frozen_string_literal: true

module CDC
  module Concurrent
    # Executes one concurrent-safe processor using Async tasks.
    class ProcessorPool
      # @param processor [CDC::Core::Processor]
      # @param concurrency [Integer]
      # @param timeout [Float, nil]
      # @param preserve_order [Boolean]
      def initialize(processor:, concurrency: 100, timeout: nil, preserve_order: true)
        validate_processor!(processor)

        @processor = processor
        @configuration = Configuration.new(concurrency:, timeout:, preserve_order:)
        @shutdown = false
      end

      # @param event [CDC::Core::ChangeEvent]
      # @return [CDC::Core::ProcessorResult]
      def process(event)
        raise ShutdownError, "processor pool has been shut down" if @shutdown

        process_one(event)
      end

      # @param events [Array<CDC::Core::ChangeEvent>]
      # @return [Array<CDC::Core::ProcessorResult>]
      def process_many(events)
        raise ShutdownError, "processor pool has been shut down" if @shutdown
        return empty_results if events.empty?

        # @type var indexed_results: Array[[Integer, CDC::Core::ProcessorResult]]
        indexed_results = []

        process_batch(events, indexed_results)

        indexed_results.sort_by!(&:first) if @configuration.preserve_order
        indexed_results.map(&:last).freeze
      end

      # @return [void]
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
