# frozen_string_literal: true

module CommitContext
  module Sections
    class RecentLog
      def initialize(limit:)
        @limit = limit
      end

      def title = "Recent commits"

      def render(git)
        out = git.recent_log(limit: @limit)
        out.empty? ? "(none)\n" : out
      end
    end
  end
end
