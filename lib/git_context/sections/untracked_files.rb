# frozen_string_literal: true

module GitContext
  module Sections
    class UntrackedFiles
      def title = "Untracked files"

      def render(git)
        files = git.untracked_files
        return "(none)\n" if files.empty?

        files.map { |f| "#{f}:\n#{git.read_file(f)}" }.join("\n")
      end
    end
  end
end
