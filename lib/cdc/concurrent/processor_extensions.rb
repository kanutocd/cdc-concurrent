# frozen_string_literal: true

module CDC
  # Optional concurrent runtime adapter for cdc-core processors.
  module Concurrent
    # Adds concurrent-safe declarations to CDC::Core::Processor subclasses.
    module ProcessorExtensions
      # Class methods added to CDC::Core::Processor.
      module ClassMethods
        # Declare this processor safe for concurrent execution.
        def concurrent_safe!
          @concurrent_safe = true
        end

        # @return [Boolean] whether instances are concurrent-safe.
        def concurrent_safe?
          @concurrent_safe == true
        end
      end

      # @return [Boolean] whether this processor instance is concurrent-safe.
      def concurrent_safe?
        self.class.instance_variable_get(:@concurrent_safe) == true
      end
    end

    # Installs concurrent-safe declarations on CDC::Core::Processor.
    #
    # @return [void]
    def self.install_processor_extensions!
      CDC::Core::Processor.extend(ProcessorExtensions::ClassMethods)
      CDC::Core::Processor.include(ProcessorExtensions)
    end
  end
end

CDC::Concurrent.install_processor_extensions!
