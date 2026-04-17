# frozen_string_literal: true

module GitContext
  module RepoAudit
    class Preset < GitContext::Preset
      def name = "repo-audit"
      def default_tokens = %w[gitignore_gaps tracked_secrets missing_standard_files]
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
