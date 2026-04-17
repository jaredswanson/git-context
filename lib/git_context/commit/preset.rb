# frozen_string_literal: true

module GitContext
  module Commit
    # Default section composition for pre-commit context gathering.
    class Preset < GitContext::Preset
      def name
        "commit"
      end

      def default_tokens
        %w[status staged_diff unstaged_diff recent_log file_history untracked_files]
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
