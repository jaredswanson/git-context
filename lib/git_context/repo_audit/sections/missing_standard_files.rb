# frozen_string_literal: true

module GitContext
  module RepoAudit
    module Sections
      # Reports which conventional repo files are missing.
      # Matches README*/LICENSE* case-insensitively; .gitignore exactly.
      class MissingStandardFiles
        STANDARDS = [
          { label: "README",     prefix: "readme",   exact: false },
          { label: "LICENSE",    prefix: "license",  exact: false },
          { label: ".gitignore", prefix: ".gitignore", exact: true }
        ].freeze

        def title
          "Missing standard files"
        end

        def render(git)
          missing = STANDARDS.reject { |s| present?(git.repo_path, s) }
          return "All standard files present\n" if missing.empty?

          missing.map { |s| "- #{s[:label]}" }.join("\n") + "\n"
        end

        private

        def present?(repo_path, standard)
          entries = Dir.children(repo_path)
          if standard[:exact]
            entries.include?(standard[:prefix])
          else
            entries.any? { |e| e.downcase.start_with?(standard[:prefix]) }
          end
        end
      end
    end
  end
end
