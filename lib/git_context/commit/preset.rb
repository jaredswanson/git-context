# frozen_string_literal: true

module GitContext
  module Commit
    # Default section composition for pre-commit context gathering.
    # Knows the token→section mapping so the CLI can resolve flag names.
    class Preset
      def name
        "commit"
      end

      def default_tokens
        %w[status staged_diff unstaged_diff recent_log file_history untracked_files]
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
          "status"           => -> { Sections::Status.new },
          "staged_diff"      => -> { Sections::StagedDiff.new(max_lines_per_file: 200) },
          "unstaged_diff"    => -> { Sections::UnstagedDiff.new(max_lines_per_file: 200) },
          "recent_log"       => -> { Sections::RecentLog.new(limit: 5) },
          "file_history"     => -> { Sections::FileHistory.new(limit: 3) },
          "untracked_files"  => -> { Sections::UntrackedFiles.new }
        }
      end
    end
  end
end
