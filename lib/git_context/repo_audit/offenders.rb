# frozen_string_literal: true

module GitContext
  module RepoAudit
    # Shared data module: the list of filename patterns that commonly indicate
    # a repo-hygiene problem. Grouped by category so sections can report them
    # meaningfully.
    module Offenders
      CATEGORIES = {
        env_files:      %w[.env .env.*],
        dep_dirs:       %w[node_modules/ vendor/bundle/],
        os_editor:      %w[.DS_Store .idea/ .vscode/ *.swp],
        build_runtime:  %w[tmp/ log/ *.log coverage/],
        databases:      %w[*.sqlite3]
      }.freeze

      SECRET_PATTERNS = %w[*.pem *.key id_rsa* *credentials* *secret*].freeze

      ALL_PATTERNS = CATEGORIES.values.flatten.freeze

      def self.all_patterns
        ALL_PATTERNS
      end

      # Match a relative path against one offender pattern.
      # Directory patterns (ending in "/") match any path under that directory.
      # Glob patterns are matched against both the full path and the basename
      # so that "*.log" catches "errors.log" and "foo/bar/baz.log".
      # Plain names (no slash, no glob) match the basename only.
      def self.matches?(path, pattern)
        if pattern.end_with?("/")
          prefix = pattern
          path.start_with?(prefix) || path.include?("/#{prefix}")
        elsif pattern.include?("*") || pattern.include?("?")
          File.fnmatch(pattern, path, File::FNM_PATHNAME) ||
            File.fnmatch(pattern, File.basename(path))
        else
          File.basename(path) == pattern
        end
      end
    end
  end
end
