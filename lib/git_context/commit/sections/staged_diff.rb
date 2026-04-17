# frozen_string_literal: true

require "git_context/truncated_diff"

module GitContext
  module Commit
    module Sections
      class StagedDiff
        def initialize(max_lines_per_file:)
          @max = max_lines_per_file
        end

        def title = "Staged changes"

        def render(git)
          raw = git.diff(staged: true)
          return "(none)\n" if raw.empty?

          TruncatedDiff.new(raw, max_lines_per_file: @max).to_s
        end
      end
    end
  end
end
