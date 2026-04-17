# frozen_string_literal: true

require "test_helper"
require "git_context/repo_audit/sections/missing_standard_files"

class MissingStandardFilesSectionTest < Minitest::Test
  include TempRepo

  def test_title
    section = GitContext::RepoAudit::Sections::MissingStandardFiles.new
    assert_equal "Missing standard files", section.title
  end

  def test_reports_missing_files
    in_temp_repo do |dir|
      section = GitContext::RepoAudit::Sections::MissingStandardFiles.new
      out = section.render(GitContext::Git.new(dir))

      assert_includes out, "README"
      assert_includes out, "LICENSE"
      assert_includes out, ".gitignore"
    end
  end

  def test_reports_all_present_when_present
    in_temp_repo do |dir|
      write_file("README.md", "x")
      write_file("LICENSE", "x")
      write_file(".gitignore", "x")

      section = GitContext::RepoAudit::Sections::MissingStandardFiles.new
      out = section.render(GitContext::Git.new(dir))

      assert_match(/All standard files present/, out)
    end
  end

  def test_readme_match_is_case_insensitive
    in_temp_repo do |dir|
      write_file("readme.md", "x")

      section = GitContext::RepoAudit::Sections::MissingStandardFiles.new
      out = section.render(GitContext::Git.new(dir))

      refute_match(/README/, out)
    end
  end

  def test_readme_prefix_match
    in_temp_repo do |dir|
      write_file("README.rst", "x")

      section = GitContext::RepoAudit::Sections::MissingStandardFiles.new
      out = section.render(GitContext::Git.new(dir))

      refute_match(/^README/, out.strip)
    end
  end
end
