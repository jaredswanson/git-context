# frozen_string_literal: true

module GitContext
  module Commit
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
end
