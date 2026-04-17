# frozen_string_literal: true

require "test_helper"

class GitTest < Minitest::Test
  include TempRepo

  def test_status_returns_short_status_output
    in_temp_repo do
      write_file("a.txt", "hello")
      git_client = GitContext::Git.new(Dir.pwd)

      assert_includes git_client.status, "?? a.txt"
    end
  end

  def test_diff_unstaged_shows_working_tree_changes
    in_temp_repo do
      write_file("a.txt", "one\n")
      git("add a.txt")
      git("commit -q -m initial")
      write_file("a.txt", "two\n")

      diff = GitContext::Git.new(Dir.pwd).diff(staged: false)

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

      staged = GitContext::Git.new(Dir.pwd).diff(staged: true)

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

      log = GitContext::Git.new(Dir.pwd).recent_log(limit: 5)

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

      modified = GitContext::Git.new(Dir.pwd).modified_files

      assert_includes modified, "a.txt"
      refute_includes modified, "new.txt"
    end
  end

  def test_untracked_files_lists_new_files
    in_temp_repo do
      write_file("new.txt", "x")

      untracked = GitContext::Git.new(Dir.pwd).untracked_files

      assert_includes untracked, "new.txt"
    end
  end

  def test_read_file_resolves_relative_to_repo_root
    in_temp_repo do |dir|
      write_file("sub/thing.txt", "payload\n")

      # Call from a different directory to prove path resolution is vs. repo root.
      Dir.chdir(Dir.tmpdir) do
        assert_equal "payload\n", GitContext::Git.new(dir).read_file("sub/thing.txt")
      end
    end
  end

  def test_read_file_returns_directory_marker_for_directories
    in_temp_repo do
      Dir.mkdir("adir")
      out = GitContext::Git.new(Dir.pwd).read_file("adir")
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

      out = GitContext::Git.new(Dir.pwd).file_log("a.txt", limit: 5)

      assert_includes out, "add a"
      assert_includes out, "update a"
    end
  end
end

class GitLsFilesTest < Minitest::Test
  include TempRepo

  def test_ls_files_returns_tracked_files
    in_temp_repo do |dir|
      write_file("a.rb", "a")
      write_file("sub/b.rb", "b")
      git("add -A")
      git("commit -q -m init")

      files = GitContext::Git.new(dir).ls_files
      assert_includes files, "a.rb"
      assert_includes files, "sub/b.rb"
    end
  end

  def test_ls_files_is_empty_for_fresh_repo
    in_temp_repo do |dir|
      assert_empty GitContext::Git.new(dir).ls_files
    end
  end
end

class GitIgnoredTest < Minitest::Test
  include TempRepo

  def test_ignored_returns_true_when_path_matches_gitignore
    in_temp_repo do |dir|
      write_file(".gitignore", "*.log\n")
      assert GitContext::Git.new(dir).ignored?("errors.log")
    end
  end

  def test_ignored_returns_false_when_path_does_not_match
    in_temp_repo do |dir|
      write_file(".gitignore", "*.log\n")
      refute GitContext::Git.new(dir).ignored?("app.rb")
    end
  end

  def test_ignored_returns_false_when_no_gitignore
    in_temp_repo do |dir|
      refute GitContext::Git.new(dir).ignored?("anything.log")
    end
  end
end

class GitWalkWorkingTreeTest < Minitest::Test
  include TempRepo

  def test_walk_working_tree_includes_tracked_and_untracked_files
    in_temp_repo do |dir|
      write_file("tracked.rb", "x")
      git("add tracked.rb")
      git("commit -q -m init")
      write_file("untracked.txt", "y")

      paths = GitContext::Git.new(dir).walk_working_tree

      assert_includes paths, "tracked.rb"
      assert_includes paths, "untracked.txt"
    end
  end

  def test_walk_working_tree_prunes_dot_git
    in_temp_repo do |dir|
      write_file("app.rb", "x")

      paths = GitContext::Git.new(dir).walk_working_tree

      refute paths.any? { |p| p.start_with?(".git") },
             "Expected .git to be pruned, but found: #{paths.select { |p| p.start_with?('.git') }.inspect}"
    end
  end

  def test_walk_working_tree_appends_slash_to_directories
    in_temp_repo do |dir|
      write_file("sub/file.rb", "x")

      paths = GitContext::Git.new(dir).walk_working_tree

      assert_includes paths, "sub/"
    end
  end

  def test_entries_returns_direct_children_of_repo_root
    in_temp_repo do |dir|
      write_file("a.rb", "x")
      write_file("b.rb", "x")
      Dir.mkdir(File.join(dir, "subdir"))

      children = GitContext::Git.new(dir).entries

      assert_includes children, "a.rb"
      assert_includes children, "b.rb"
      assert_includes children, "subdir"
    end
  end

  def test_entries_returns_children_of_subpath
    in_temp_repo do |dir|
      write_file("lib/foo.rb", "x")
      write_file("lib/bar.rb", "x")

      children = GitContext::Git.new(dir).entries("lib")

      assert_includes children, "foo.rb"
      assert_includes children, "bar.rb"
    end
  end
end
