# frozen_string_literal: true

module GitContext
  # Composes sections into a single git-context string. Collaborators
  # (git + sections) are injected — Report itself has no knowledge of shell
  # or git commands and no default composition.
  class Report
    def initialize(git:, sections:)
      @git = git
      @sections = sections
    end

    def to_s
      @sections.map { |s| render_section(s) }.join("\n")
    end

    private

    def render_section(section)
      body = section.render(@git)
      body = body.end_with?("\n") ? body : "#{body}\n"
      "## #{section.title}\n#{body}"
    end
  end
end
