# frozen_string_literal: true

require_relative "lib/commit_context/version"

Gem::Specification.new do |spec|
  spec.name = "commit-context"
  spec.version = CommitContext::VERSION
  spec.authors = ["jared"]
  spec.email = ["jared@swansoncloud.com"]

  spec.summary = "Gathers git state into a single commit-context report suitable for AI consumption."
  spec.description = "Runs a curated set of git commands (status, diffs, recent log, per-file history, untracked file contents) and assembles the output into one structured report. Ships a `commit_context` CLI and a library API composed of small, injectable section objects."
  spec.homepage = "https://github.com/jaredmswanson/commit-context"
  spec.required_ruby_version = ">= 3.2.0"
  spec.license = "MIT"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage

  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore test/])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
end
