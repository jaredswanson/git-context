# frozen_string_literal: true

module GitContext
  module RepoInit
    module GitignorePatterns
      PYTHON = [
        "__pycache__/",
        "*.pyc",
        "/dist/",
        "/build/",
        "*.egg-info/",
        ".venv/",
        "venv/",
        ".pytest_cache/",
        ".ruff_cache/"
      ].freeze
    end
  end
end
