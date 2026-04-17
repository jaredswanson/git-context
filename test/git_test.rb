# frozen_string_literal: true

require "test_helper"

class GitTest < Minitest::Test
  include TempRepo

  def test_status_returns_short_status_output
    in_temp_repo do
      write_file("a.txt", "hello")
      git_client = CommitContext::Git.new(Dir.pwd)

      assert_includes git_client.status, "?? a.txt"
    end
  end

  def test_diff_unstaged_shows_working_tree_changes
    in_temp_repo do
      write_file("a.txt", "one\n")
      git("add a.txt")
      git("commit -q -m initial")
      write_file("a.txt", "two\n")

      diff = CommitContext::Git.new(Dir.pwd).diff(staged: false)

      assert_includes diff, "-one"
      assert_includes diff, "+two"
    end
  end

  def test_diff_staged_shows_index_changes_only
    in_temp_repo do
      write_file("a.txt", "one\n")
      git("add a.txt")
      git("commit -q -m initial")
      write_file("a.txt", "staged\n")
      git("add a.txt")
      write_file("a.txt", "unstaged\n")

      staged = CommitContext::Git.new(Dir.pwd).diff(staged: true)

      assert_includes staged, "+staged"
      refute_includes staged, "+unstaged"
    end
  end

  def test_recent_log_returns_oneline_entries
    in_temp_repo do
      write_file("a.txt", "1")
      git("add a.txt")
      git("commit -q -m 'first commit'")
      write_file("b.txt", "2")
      git("add b.txt")
      git("commit -q -m 'second commit'")

      log = CommitContext::Git.new(Dir.pwd).recent_log(limit: 5)

      assert_includes log, "first commit"
      assert_includes log, "second commit"
    end
  end

  def test_modified_files_lists_tracked_changes
    in_temp_repo do
      write_file("a.txt", "1")
      git("add a.txt")
      git("commit -q -m initial")
      write_file("a.txt", "2")
      write_file("new.txt", "new")

      modified = CommitContext::Git.new(Dir.pwd).modified_files

      assert_includes modified, "a.txt"
      refute_includes modified, "new.txt"
    end
  end

  def test_untracked_files_lists_new_files
    in_temp_repo do
      write_file("new.txt", "x")

      untracked = CommitContext::Git.new(Dir.pwd).untracked_files

      assert_includes untracked, "new.txt"
    end
  end

  def test_read_file_resolves_relative_to_repo_root
    in_temp_repo do |dir|
      write_file("sub/thing.txt", "payload\n")

      # Call from a different directory to prove path resolution is vs. repo root.
      Dir.chdir(Dir.tmpdir) do
        assert_equal "payload\n", CommitContext::Git.new(dir).read_file("sub/thing.txt")
      end
    end
  end

  def test_read_file_returns_directory_marker_for_directories
    in_temp_repo do
      Dir.mkdir("adir")
      out = CommitContext::Git.new(Dir.pwd).read_file("adir")
      assert_includes out, "(directory)"
    end
  end

  def test_file_log_returns_recent_commits_for_path
    in_temp_repo do
      write_file("a.txt", "1")
      git("add a.txt")
      git("commit -q -m 'add a'")
      write_file("a.txt", "2")
      git("add a.txt")
      git("commit -q -m 'update a'")

      out = CommitContext::Git.new(Dir.pwd).file_log("a.txt", limit: 5)

      assert_includes out, "add a"
      assert_includes out, "update a"
    end
  end
end
