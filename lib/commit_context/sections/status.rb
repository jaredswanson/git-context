# frozen_string_literal: true

module CommitContext
  module Sections
    class Status
      def title = "Status"

      def render(git)
        out = git.status
        out.empty? ? "(clean)\n" : out
      end
    end
  end
end
