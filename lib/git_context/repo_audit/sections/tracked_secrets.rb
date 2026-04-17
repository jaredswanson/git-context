# frozen_string_literal: true

module GitContext
  module RepoAudit
    module Sections
      # Lists tracked files that match common-offender or secret-shaped
      # patterns. These are files already committed that probably shouldn't
      # be — remediation is `git rm --cached <path>` plus a .gitignore entry.
      class TrackedSecrets
        def title
          "Tracked secrets"
        end

        def render(git)
          patterns = Offenders.all_patterns + Offenders::SECRET_PATTERNS
          flagged = git.ls_files.select do |path|
            patterns.any? { |p| Offenders.matches?(path, p) }
          end

          return "No tracked secrets\n" if flagged.empty?

          lines = flagged.map do |path|
            "- #{path}  (remediate: git rm --cached #{path} && add to .gitignore)"
          end
          lines.join("\n") + "\n"
        end
      end
    end
  end
end
