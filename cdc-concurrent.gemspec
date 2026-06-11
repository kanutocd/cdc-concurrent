# frozen_string_literal: true

require_relative "lib/cdc/concurrent/version"

Gem::Specification.new do |spec|
  spec.name = "cdc-concurrent"
  spec.version = CDC::Concurrent::VERSION
  spec.authors = ["Ken C. Demanawa"]
  spec.email = ["kenneth.c.demanawa@gmail.com"]

  spec.summary = "Optional I/O-concurrent Change Data Capture (CDC) runtime for cdc-core."
  spec.description = <<~TEXT
    cdc-concurrent provides optional Async-backed I/O-concurrent execution for
    cdc-core. It accelerates I/O-bound PostgreSQL Change Data Capture (CDC)
    event processing while preserving the cdc-core programming model.
  TEXT
  spec.homepage = "https://kanutocd.github.io/cdc-concurrent"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.4.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["documentation_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/kanutocd/cdc-concurrent"
  spec.metadata["changelog_uri"] = "https://github.com/kanutocd/cdc-concurrent/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir[
    "lib/**/*.rb",
    "sig/**/*.rbs",
    "benchmark/**/*.rb",
    "benchmark/**/*.md",
    "README.md",
    "CHANGELOG.md",
    "LICENSE.txt"
  ]
  spec.require_paths = ["lib"]

  spec.add_dependency "async", "~> 2.0"
  spec.add_dependency "cdc-core", "~> 0.1", ">= 0.1.3"
end
