# frozen_string_literal: true

require "find"

module GitContext
  module RepoAudit
    module Sections
      # Reports paths in the working tree that match common-offender patterns
      # and are NOT currently covered by .gitignore. Groups findings by
      # offender category.
      class GitignoreGaps
        def title
          "Gitignore gaps"
        end

        def render(git)
          findings = scan(git)
          return "No gaps found\n" if findings.empty?

          format(findings)
        end

        private

        def scan(git)
          grouped = Hash.new { |h, k| h[k] = [] }

          walk(git.repo_path).each do |relative_path|
            category = classify(relative_path)
            next unless category
            next if git.ignored?(relative_path)

            grouped[category] << relative_path
          end

          grouped
        end

        def walk(root)
          paths = []
          Find.find(root) do |path|
            base = File.basename(path)
            if File.directory?(path) && base == ".git"
              Find.prune
            end
            next if path == root

            rel = path.sub(%r{\A#{Regexp.escape(root)}/?}, "")
            paths << (File.directory?(path) ? "#{rel}/" : rel)
          end
          paths
        end

        def classify(path)
          Offenders::CATEGORIES.each do |category, patterns|
            return category if patterns.any? { |p| Offenders.matches?(path, p) }
          end
          nil
        end

        def format(grouped)
          grouped.map do |category, paths|
            unique = paths.uniq.sort
            "#{category}:\n" + unique.map { |p| "- #{p}" }.join("\n") + "\n"
          end.join("\n")
        end
      end
    end
  end
end
