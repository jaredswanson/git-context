# frozen_string_literal: true

require "json"

module GitContext
  module RepoInit
    # Detects the technology stack(s) present in a repository by inspecting
    # root-level entries. Collaborates with a Git instance (real or fake) via
    # #entries and #read_file.
    class StackDetector
      OpenSourceResult = Struct.new(:value, :signals, keyword_init: true)

      DETECTION_ORDER = %i[ruby_gem claude_plugin node python].freeze

      def initialize(git:)
        @git = git
        @root_entries = git.entries(".").to_a
      end

      # Returns Array<Symbol> of detected stacks in detection order.
      # Falls back to [:generic] when nothing matches.
      def stacks
        detected = DETECTION_ORDER.select { |stack| detected?(stack) }
        detected.empty? ? [:generic] : detected
      end

      # Returns an OpenSourceResult struct with :value (Bool) and :signals (Array<String>).
      def likely_open_source?
        signals = []

        signals << "gemspec present"        if gemspec_present?
        signals << ".claude-plugin manifest present" if claude_plugin_present?
        signals << "package.json without private:true" if public_package_json?

        OpenSourceResult.new(value: signals.any?, signals: signals)
      end

      private

      def detected?(stack)
        case stack
        when :ruby_gem     then gemspec_present?
        when :claude_plugin then claude_plugin_present?
        when :node         then @root_entries.include?("package.json")
        when :python       then @root_entries.include?("pyproject.toml") ||
                                @root_entries.include?("setup.py")
        else raise ArgumentError, "unknown stack: #{stack}"
        end
      end

      def gemspec_present?
        @root_entries.any? { |e| e.end_with?(".gemspec") }
      end

      def claude_plugin_present?
        @root_entries.include?(".claude-plugin")
      end

      def public_package_json?
        return false unless @root_entries.include?("package.json")

        contents = @git.read_file("package.json")
        parsed = JSON.parse(contents)
        parsed["private"] != true
      rescue JSON::ParserError
        false
      end
    end
  end
end
