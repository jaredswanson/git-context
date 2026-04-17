# frozen_string_literal: true

module GitContext
  module RepoInit
    # Curated gitignore pattern sets keyed by stack symbol.
    # Each constant is a frozen array of gitignore-format strings.
    # Use .for to retrieve a single stack's patterns, or .merged to
    # obtain the deduplicated union across multiple stacks.
    module GitignorePatterns
    end
  end
end

require "git_context/repo_init/gitignore_patterns/ruby_gem"
require "git_context/repo_init/gitignore_patterns/node"
require "git_context/repo_init/gitignore_patterns/python"
require "git_context/repo_init/gitignore_patterns/claude_plugin"
require "git_context/repo_init/gitignore_patterns/generic"

module GitContext
  module RepoInit
    module GitignorePatterns
      STACK_MAP = {
        ruby_gem:     RUBY_GEM,
        node:         NODE,
        python:       PYTHON,
        claude_plugin: CLAUDE_PLUGIN,
        generic:      GENERIC
      }.freeze

      def self.for(stack)
        STACK_MAP.fetch(stack, [])
      end

      def self.merged(stacks)
        stacks.flat_map { |s| GitignorePatterns.for(s) }.uniq
      end
    end
  end
end
