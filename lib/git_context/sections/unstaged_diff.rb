# frozen_string_literal: true

require "git_context/truncated_diff"

module GitContext
  module Sections
    class UnstagedDiff
      def initialize(max_lines_per_file:)
        @max = max_lines_per_file
      end

      def title = "Unstaged changes"

      def render(git)
        raw = git.diff(staged: false)
        return "(none)\n" if raw.empty?

        TruncatedDiff.new(raw, max_lines_per_file: @max).to_s
      end
    end
  end
end
