# frozen_string_literal: true

require "test_helper"

class WorkspaceTest < Minitest::Test
  include TempRepo

  def setup
    @dir = Dir.mktmpdir("workspace_test")
    @workspace = GitContext::Workspace.new(@dir)
  end

  def teardown
    FileUtils.remove_entry(@dir)
  end

  def test_write_file_creates_file
    @workspace.write_file("hello.txt", "hello world")

    assert File.exist?(File.join(@dir, "hello.txt"))
    assert_equal "hello world", File.read(File.join(@dir, "hello.txt"))
  end

  def test_write_file_creates_nested_directories
    @workspace.write_file("subdir/nested/file.txt", "contents")

    assert File.exist?(File.join(@dir, "subdir/nested/file.txt"))
  end

  def test_append_file_appends_to_existing_file
    @workspace.write_file("log.txt", "first line\n")
    @workspace.append_file("log.txt", "second line\n")

    assert_equal "first line\nsecond line\n", File.read(File.join(@dir, "log.txt"))
  end

  def test_write_file_raises_on_path_escape
    assert_raises(ArgumentError) { @workspace.write_file("../escape.txt", "bad") }
    assert_raises(ArgumentError) { @workspace.write_file("../../etc/passwd", "bad") }
  end

  def test_file_exists_returns_true_when_file_present
    File.write(File.join(@dir, "exists.txt"), "yes")

    assert @workspace.file_exists?("exists.txt")
  end

  def test_file_exists_returns_false_when_absent
    refute @workspace.file_exists?("no_such_file.txt")
  end

  def test_read_lines_returns_lines_from_file
    File.write(File.join(@dir, "lines.txt"), "one\ntwo\nthree\n")

    assert_equal ["one\n", "two\n", "three\n"], @workspace.read_lines("lines.txt")
  end

  def test_read_lines_returns_empty_array_when_absent
    assert_equal [], @workspace.read_lines("no_such_file.txt")
  end

  def test_run_gh_returns_failed_result_when_gh_missing
    # Force a workspace that reports gh as absent via which
    workspace = WorkspaceWithoutGh.new(@dir)
    result = workspace.run_gh("--version")

    refute result.success?
    assert_match(/not found/i, result.error)
  end

  def test_run_gh_success_or_skip_if_absent
    skip "gh not on PATH" unless @workspace.which("gh")

    result = @workspace.run_gh("--version")

    assert result.success?
    refute result.output.empty?
  end

  def test_which_returns_true_for_known_binary
    # ruby is always present in this test environment
    assert @workspace.which("ruby")
  end

  def test_which_returns_false_for_missing_binary
    refute @workspace.which("this_binary_does_not_exist_xyz_abc_123")
  end

  # Helper subclass that pretends gh is missing, so we can test the failure
  # path without actually needing gh to be absent from the system.
  class WorkspaceWithoutGh < GitContext::Workspace
    def which(binary)
      return false if binary == "gh"

      super
    end
  end
end
