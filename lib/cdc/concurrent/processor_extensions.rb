# frozen_string_literal: true

module CDC
  # Optional concurrent runtime adapter for cdc-core processors.
  module Concurrent
    # Adds concurrent-safe declarations to CDC::Core::Processor subclasses.
    #
    # cdc-concurrent requires processors to explicitly opt in before they can be
    # executed by Async-based runtime pools. The declaration is intentionally
    # separate from ractor_safe! so processor authors can describe the execution
    # model they support.
    module ProcessorExtensions
      # Class-level declarations added to CDC::Core::Processor.
      module ClassMethods
        # Marks the processor class as safe for cdc-concurrent execution.
        #
        # This declaration means processor instances may be executed by the
        # Async task fan-out runtime. It does not imply Ractor safety.
        #
        # @return [true] Always returns true after setting the declaration flag.
        def concurrent_safe!
          @concurrent_safe = true
        end

        # Reports whether the processor class declared concurrent_safe!.
        #
        # @return [Boolean] True when this processor class opted into concurrent execution.
        def concurrent_safe?
          @concurrent_safe == true
        end
      end

      # Reports whether this processor instance is safe for concurrent execution.
      #
      # @return [Boolean] True when the processor class declared concurrent_safe!.
      def concurrent_safe?
        self.class.instance_variable_get(:@concurrent_safe) == true
      end
    end

    # Installs concurrent-safe declarations on CDC::Core::Processor.
    #
    # @return [void] Does not return a useful value.
    def self.install_processor_extensions!
      CDC::Core::Processor.extend(ProcessorExtensions::ClassMethods)
      CDC::Core::Processor.include(ProcessorExtensions)
    end
  end
end

CDC::Concurrent.install_processor_extensions!
