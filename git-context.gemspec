# frozen_string_literal: true

require_relative "lib/git_context/version"

Gem::Specification.new do |spec|
  spec.name = "git-context"
  spec.version = GitContext::VERSION
  spec.authors = ["jared"]
  spec.email = ["jared@swansoncloud.com"]

  spec.summary = "Composable gem that gathers structured git state as context for AI tools and humans."
  spec.description = "Composes small, duck-typed 'section' objects into structured git-state reports. Ships presets for common workflows (pre-commit snapshot, repo hygiene audit) plus a CLI (`git-context <preset>`) and Ruby API for building custom compositions."
  spec.homepage = "https://github.com/jaredmswanson/git-context"
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
