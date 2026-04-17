# frozen_string_literal: true

require "test_helper"
require "git_context/repo_audit/sections/gitignore_gaps"

class GitignoreGapsSectionTest < Minitest::Test
  include TempRepo

  def test_title
    assert_equal "Gitignore gaps", GitContext::RepoAudit::Sections::GitignoreGaps.new.title
  end

  def test_flags_unignored_env_file_in_working_tree
    in_temp_repo do |dir|
      write_file(".env", "SECRET=1")

      out = GitContext::RepoAudit::Sections::GitignoreGaps.new.render(GitContext::Git.new(dir))
      assert_match(/env_files/, out)
      assert_match(/\.env/, out)
    end
  end

  def test_does_not_flag_already_ignored_file
    in_temp_repo do |dir|
      write_file(".gitignore", ".env\n")
      write_file(".env", "SECRET=1")

      out = GitContext::RepoAudit::Sections::GitignoreGaps.new.render(GitContext::Git.new(dir))
      refute_match(/^- \.env$/, out)
    end
  end

  def test_flags_node_modules_directory_contents
    in_temp_repo do |dir|
      write_file("node_modules/lib/a.js", "x")

      out = GitContext::RepoAudit::Sections::GitignoreGaps.new.render(GitContext::Git.new(dir))
      assert_match(/dep_dirs/, out)
      assert_match(%r{node_modules/}, out)
    end
  end

  def test_none_marker_when_clean
    in_temp_repo do |dir|
      write_file("app.rb", "x")

      out = GitContext::RepoAudit::Sections::GitignoreGaps.new.render(GitContext::Git.new(dir))
      assert_match(/No gaps found/, out)
    end
  end

  def test_groups_findings_by_category
    in_temp_repo do |dir|
      write_file(".env", "x")
      write_file("errors.log", "x")

      out = GitContext::RepoAudit::Sections::GitignoreGaps.new.render(GitContext::Git.new(dir))
      assert_match(/env_files:/, out)
      assert_match(/build_runtime:/, out)
    end
  end

  def test_skips_dot_git_directory
    in_temp_repo do |dir|
      out = GitContext::RepoAudit::Sections::GitignoreGaps.new.render(GitContext::Git.new(dir))
      refute_match(/\.git\//, out)
    end
  end
end
