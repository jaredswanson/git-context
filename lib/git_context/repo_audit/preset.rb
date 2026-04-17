# frozen_string_literal: true

module GitContext
  module RepoAudit
    # Default section composition for repo hygiene audit.
    class Preset < GitContext::Preset
      def name
        "repo-audit"
      end

      def default_tokens
        %w[gitignore_gaps tracked_secrets missing_standard_files]
      end

      private

      def factories
        {
          "gitignore_gaps"         => -> { Sections::GitignoreGaps.new },
          "tracked_secrets"        => -> { Sections::TrackedSecrets.new },
          "missing_standard_files" => -> { Sections::MissingStandardFiles.new }
        }
      end
    end
  end
end
