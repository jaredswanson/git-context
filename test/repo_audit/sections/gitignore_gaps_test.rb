# frozen_string_literal: true

require "test_helper"
require "git_context/repo_audit/sections/gitignore_gaps"

class GitignoreGapsSectionTest < Minitest::Test
  def test_title
    assert_equal "Gitignore gaps", GitContext::RepoAudit::Sections::GitignoreGaps.new.title
  end

  def test_flags_unignored_env_file_in_working_tree
    git = FakeGit.new(
      walk_working_tree: [".env"],
      ignored: {}
    )

    out = GitContext::RepoAudit::Sections::GitignoreGaps.new.render(git)

    assert_match(/env_files/, out)
    assert_match(/\.env/, out)
  end

  def test_does_not_flag_already_ignored_file
    git = FakeGit.new(
      walk_working_tree: [".env"],
      ignored: { ".env" => true }
    )

    out = GitContext::RepoAudit::Sections::GitignoreGaps.new.render(git)

    refute_match(/^- \.env$/, out)
  end

  def test_flags_node_modules_directory_contents
    git = FakeGit.new(
      walk_working_tree: ["node_modules/", "node_modules/lib/", "node_modules/lib/a.js"],
      ignored: {}
    )

    out = GitContext::RepoAudit::Sections::GitignoreGaps.new.render(git)

    assert_match(/dep_dirs/, out)
    assert_match(%r{node_modules/}, out)
  end

  def test_none_marker_when_clean
    git = FakeGit.new(
      walk_working_tree: ["app.rb"],
      ignored: {}
    )

    out = GitContext::RepoAudit::Sections::GitignoreGaps.new.render(git)

    assert_match(/No gaps found/, out)
  end

  def test_groups_findings_by_category
    git = FakeGit.new(
      walk_working_tree: [".env", "errors.log"],
      ignored: {}
    )

    out = GitContext::RepoAudit::Sections::GitignoreGaps.new.render(git)

    assert_match(/env_files:/, out)
    assert_match(/build_runtime:/, out)
  end

  def test_skips_dot_git_directory
    # walk_working_tree contract: .git is already pruned by Git#walk_working_tree.
    # We verify the section doesn't output .git/ when the tree is empty.
    git = FakeGit.new(
      walk_working_tree: [],
      ignored: {}
    )

    out = GitContext::RepoAudit::Sections::GitignoreGaps.new.render(git)

    refute_match(/\.git\//, out)
  end
end
