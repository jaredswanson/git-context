# frozen_string_literal: true

module GitContext
  # Composes sections into a single git-context string. Collaborators
  # (git + sections) are injected — Report itself has no knowledge of shell
  # or git commands.
  class Report
    DEFAULT_SECTIONS = lambda do
      [
        Sections::Status.new,
        Sections::StagedDiff.new(max_lines_per_file: 200),
        Sections::UnstagedDiff.new(max_lines_per_file: 200),
        Sections::RecentLog.new(limit: 5),
        Sections::FileHistory.new(limit: 3),
        Sections::UntrackedFiles.new
      ]
    end

    def initialize(git:, sections: DEFAULT_SECTIONS.call)
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
