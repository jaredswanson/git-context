# frozen_string_literal: true

module GitContext
  module RepoInit
    module GitignorePatterns
      CLAUDE_PLUGIN = [
        ".claude/local-settings.json",
        ".claude/state/"
      ].freeze
    end
  end
end
