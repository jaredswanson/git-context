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
          root_entries = git.entries
          missing = STANDARDS.reject { |s| present?(root_entries, s) }
          return "All standard files present\n" if missing.empty?

          missing.map { |s| "- #{s[:label]}" }.join("\n") + "\n"
        end

        private

        def present?(root_entries, standard)
          if standard[:exact]
            root_entries.include?(standard[:prefix])
          else
            root_entries.any? { |e| e.downcase.start_with?(standard[:prefix]) }
          end
        end
      end
    end
  end
end
