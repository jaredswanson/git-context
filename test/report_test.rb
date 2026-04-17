# frozen_string_literal: true

require "test_helper"

class FakeSection
  def initialize(title, body)
    @title = title
    @body = body
  end
  attr_reader :title
  def render(_git) = @body
end

class ReportTest < Minitest::Test
  def test_renders_each_section_with_header_and_separator
    sections = [FakeSection.new("One", "body-1\n"), FakeSection.new("Two", "body-2\n")]
    report = CommitContext::Report.new(git: Object.new, sections: sections)

    out = report.to_s

    assert_includes out, "One"
    assert_includes out, "body-1"
    assert_includes out, "Two"
    assert_includes out, "body-2"
    assert out.index("One") < out.index("Two"), "sections should appear in order"
  end

  def test_default_sections_used_when_none_passed
    git = FakeGit.new(
      status: "?? foo.rb\n",
      staged_diff: "",
      unstaged_diff: "",
      recent_log: "abc initial\n",
      modified_files: [],
      untracked_files: []
    )
    report = CommitContext::Report.new(git: git)

    out = report.to_s

    assert_includes out, "Status"
    assert_includes out, "?? foo.rb"
    assert_includes out, "Staged changes"
    assert_includes out, "Unstaged changes"
    assert_includes out, "Recent commits"
    assert_includes out, "abc initial"
    assert_includes out, "Recent history of modified files"
    assert_includes out, "Untracked files"
  end
end
