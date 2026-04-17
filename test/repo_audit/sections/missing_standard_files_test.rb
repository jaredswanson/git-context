# frozen_string_literal: true

require "test_helper"
require "git_context/repo_audit/sections/missing_standard_files"

class MissingStandardFilesSectionTest < Minitest::Test
  def test_title
    section = GitContext::RepoAudit::Sections::MissingStandardFiles.new
    assert_equal "Missing standard files", section.title
  end

  def test_reports_missing_files
    git = FakeGit.new(entries: { "." => [] })

    out = GitContext::RepoAudit::Sections::MissingStandardFiles.new.render(git)

    assert_includes out, "README"
    assert_includes out, "LICENSE"
    assert_includes out, ".gitignore"
  end

  def test_reports_all_present_when_present
    git = FakeGit.new(entries: { "." => ["README.md", "LICENSE", ".gitignore"] })

    out = GitContext::RepoAudit::Sections::MissingStandardFiles.new.render(git)

    assert_match(/All standard files present/, out)
  end

  def test_readme_match_is_case_insensitive
    git = FakeGit.new(entries: { "." => ["readme.md", "LICENSE", ".gitignore"] })

    out = GitContext::RepoAudit::Sections::MissingStandardFiles.new.render(git)

    refute_match(/README/, out)
  end

  def test_readme_prefix_match
    git = FakeGit.new(entries: { "." => ["README.rst", "LICENSE", ".gitignore"] })

    out = GitContext::RepoAudit::Sections::MissingStandardFiles.new.render(git)

    refute_match(/^README/, out.strip)
  end
end
