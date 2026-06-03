# frozen_string_literal: true

class SafeConcurrentProcessor < CDC::Core::Processor
  concurrent_safe!

  def process(event)
    CDC::Core::ProcessorResult.success({ operation: event.operation, table: event.table })
  end
end

class UnsafeConcurrentProcessor < CDC::Core::Processor
  def process(event)
    CDC::Core::ProcessorResult.success(event)
  end
end

class FailingConcurrentProcessor < CDC::Core::Processor
  concurrent_safe!

  def process(_event)
    raise "boom"
  end
end

class FlakyConcurrentProcessor < CDC::Core::Processor
  concurrent_safe!

  def process(event)
    raise "boom" if event.table == "failures"

    CDC::Core::ProcessorResult.success({ operation: event.operation, table: event.table })
  end
end

class SlowConcurrentProcessor < CDC::Core::Processor
  concurrent_safe!

  def process(event)
    sleep 0.05

    CDC::Core::ProcessorResult.success({ operation: event.operation, table: event.table })
  end
end
