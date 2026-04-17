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

      # Extensions that indicate source or documentation files. Paths with a
      # secret-shaped basename (containing "secret" or "credentials") but a
      # source extension are implementation files, not leaked credentials.
      SOURCE_EXTENSIONS = %w[.rb .py .js .ts .go .md .txt].freeze

      ALL_PATTERNS = CATEGORIES.values.flatten.freeze

      def self.all_patterns
        ALL_PATTERNS
      end

      # Match a relative path against one offender pattern.
      # Directory patterns (ending in "/") match any path under that directory.
      # Glob patterns are matched against both the full path and the basename
      # so that "*.log" catches "errors.log" and "foo/bar/baz.log".
      # Plain names (no slash, no glob) match the basename only.
      #
      # Secret-name patterns (*secret*, *credentials*) skip paths whose
      # extension identifies them as source or documentation — e.g.
      # tracked_secrets.rb is implementation, not a leaked credential.
      def self.matches?(path, pattern)
        return false if secret_name_pattern?(pattern) && source_extension?(path)

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

      # Returns true when pattern is a name-based secret glob (*secret*,
      # *credentials*) as opposed to an extension-based one (*.pem).
      def self.secret_name_pattern?(pattern)
        pattern.start_with?("*") && !pattern.start_with?("*.")
      end
      private_class_method :secret_name_pattern?

      # Returns true when path has an extension that marks it as a source or
      # documentation file.
      def self.source_extension?(path)
        SOURCE_EXTENSIONS.include?(File.extname(path))
      end
      private_class_method :source_extension?
    end
  end
end
