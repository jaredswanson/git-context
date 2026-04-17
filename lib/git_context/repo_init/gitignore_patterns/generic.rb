# frozen_string_literal: true

module GitContext
  module RepoInit
    module GitignorePatterns
      GENERIC = [
        ".DS_Store",
        "*.swp",
        "*.log",
        "/.idea/",
        "/.vscode/"
      ].freeze
    end
  end
end
