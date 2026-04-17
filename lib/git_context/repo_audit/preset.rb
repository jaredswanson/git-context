# frozen_string_literal: true

module GitContext
  module RepoAudit
    # Default section composition for repo hygiene audit.
    class Preset
      def name
        "repo-audit"
      end

      def default_tokens
        %w[gitignore_gaps tracked_secrets missing_standard_files]
      end

      def available_tokens
        factories.keys
      end

      def section_for(token)
        factory = factories.fetch(token) do
          raise ArgumentError, "unknown section '#{token}' for preset '#{name}'. Available: #{available_tokens.join(', ')}"
        end
        factory.call
      end

      def sections(tokens = default_tokens)
        tokens.map { |t| section_for(t) }
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
