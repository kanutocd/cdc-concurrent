# frozen_string_literal: true

D = Steep::Diagnostic

target :lib do
  signature "sig"
  library "cdc-core"

  check "lib"
  ignore "lib/cdc/concurrent/processor_pool.rb"

  group :async_boundary do
    check "lib/cdc/concurrent/processor_pool.rb"

    configure_code_diagnostics do |hash|
      hash[D::Ruby::NoMethod] = nil
      hash[D::Ruby::UnknownConstant] = nil
    end
  end
end
