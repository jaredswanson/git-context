# frozen_string_literal: true

module GitContext
  module RepoInit
    module GitignorePatterns
      NODE = [
        "node_modules/",
        "/dist/",
        "/build/",
        ".env",
        ".env.local",
        "npm-debug.log*",
        ".pnpm-debug.log*"
      ].freeze
    end
  end
end
