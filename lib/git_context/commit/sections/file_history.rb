# frozen_string_literal: true

module GitContext
  module Commit
    module Sections
      class FileHistory
        def initialize(limit:)
          @limit = limit
        end

        def title = "Recent history of modified files"

        def render(git)
          files = git.modified_files
          return "(none)\n" if files.empty?

          files.map { |f| "#{f}:\n#{git.file_log(f, limit: @limit)}" }.join("\n")
        end
      end
    end
  end
end
