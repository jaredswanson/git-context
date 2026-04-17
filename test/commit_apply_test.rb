# frozen_string_literal: true

require "test_helper"
require "tmpdir"

class CommitApplyTest < Minitest::Test
  # Helpers ---------------------------------------------------------------

  def fake_git(staged_diff: "diff --git a/foo.rb b/foo.rb\n+change", **opts)
    FakeGit.new(staged_diff: staged_diff, **opts)
  end

  def run_command(argv:, git: nil, stdin: StringIO.new, stdout: nil, stderr: nil)
    git    ||= fake_git
    stdout ||= StringIO.new
    stderr ||= StringIO.new
    cmd = GitContext::CommitApply.new(
      git: git, argv: argv, stdin: stdin, stdout: stdout, stderr: stderr
    )
    { cmd: cmd, stdout: stdout, stderr: stderr, git: git }
  end

  def assert_exit(expected_code, argv:, git: nil, stdin: StringIO.new)
    out = StringIO.new
    err = StringIO.new
    git ||= fake_git
    cmd = GitContext::CommitApply.new(git: git, argv: argv, stdin: stdin, stdout: out, stderr: err)
    begin
      cmd.run
      flunk "expected SystemExit(#{expected_code}) but no exit raised"
    rescue SystemExit => e
      assert_equal expected_code, e.status,
        "expected exit #{expected_code}, got #{e.status}. stderr=#{err.string.inspect}"
    end
    { stdout: out, stderr: err }
  end

  # -----------------------------------------------------------------------
  # 1. Staged changes + inline --message → action commit recorded with sha
  # -----------------------------------------------------------------------
  def test_staged_changes_with_inline_message_records_commit_action
    git = fake_git
    ctx = run_command(argv: ["--message", "Add feature"], git: git)
    ctx[:cmd].run

    assert_equal ["Add feature"], git.commits
  end

  def test_staged_changes_with_inline_message_outputs_sha
    git = fake_git
    ctx = run_command(argv: ["--message", "Add feature"], git: git)
    ctx[:cmd].run

    assert_match(/abc1234/, ctx[:stdout].string)
  end

  # -----------------------------------------------------------------------
  # 2. No staged changes + no --allow-empty → exit 1, warning emitted
  # -----------------------------------------------------------------------
  def test_no_staged_changes_without_allow_empty_exits_1
    git = fake_git(staged_diff: "")
    result = assert_exit(1, argv: ["--message", "fix"], git: git)
    assert_match(/No staged changes/, result[:stderr].string)
  end

  # -----------------------------------------------------------------------
  # 3. --allow-empty with no staged changes → commit recorded
  # -----------------------------------------------------------------------
  def test_allow_empty_with_no_staged_changes_records_commit
    git = fake_git(staged_diff: "")
    ctx = run_command(argv: ["--message", "empty commit", "--allow-empty"], git: git)
    ctx[:cmd].run

    assert_equal ["empty commit"], git.commits
  end

  # -----------------------------------------------------------------------
  # 4. Message from --message-stdin (pass StringIO as stdin)
  # -----------------------------------------------------------------------
  def test_message_from_stdin_is_used_as_commit_message
    git = fake_git
    stdin = StringIO.new("Commit from stdin\n")
    ctx = run_command(argv: ["--message-stdin"], git: git, stdin: stdin)
    ctx[:cmd].run

    assert_equal ["Commit from stdin"], git.commits
  end

  # -----------------------------------------------------------------------
  # 5. Message from --message-file <path>
  # -----------------------------------------------------------------------
  def test_message_from_file_is_used_as_commit_message
    git = fake_git
    Dir.mktmpdir do |dir|
      msg_file = File.join(dir, "commit_msg.txt")
      File.write(msg_file, "Commit from file\n")

      ctx = run_command(argv: ["--message-file", msg_file], git: git)
      ctx[:cmd].run

      assert_equal ["Commit from file"], git.commits
    end
  end

  # -----------------------------------------------------------------------
  # 6. Missing message source (no flag) → exit 2
  # -----------------------------------------------------------------------
  def test_missing_message_source_exits_2
    assert_exit(2, argv: [])
  end

  def test_missing_message_source_emits_error_to_stderr
    result = assert_exit(2, argv: [])
    assert_match(/message/, result[:stderr].string)
  end

  # -----------------------------------------------------------------------
  # 7. Whitespace-only message → exit 2
  # -----------------------------------------------------------------------
  def test_whitespace_only_message_exits_2
    assert_exit(2, argv: ["--message", "   \n  "])
  end

  def test_whitespace_only_message_emits_blank_error
    result = assert_exit(2, argv: ["--message", "   "])
    assert_match(/blank/i, result[:stderr].string)
  end

  # -----------------------------------------------------------------------
  # 8. Unstaged changes remain after commit → warning unstaged_changes_left
  # -----------------------------------------------------------------------
  def test_unstaged_changes_after_commit_emits_warning
    git = fake_git(modified_files: ["dirty.rb"])
    ctx = run_command(argv: ["--message", "fix"], git: git)
    ctx[:cmd].run

    assert_match(/unstaged/i, ctx[:stdout].string)
  end

  def test_untracked_files_after_commit_emits_warning
    git = fake_git(untracked_files: ["new_file.rb"])
    ctx = run_command(argv: ["--message", "fix"], git: git)
    ctx[:cmd].run

    assert_match(/unstaged/i, ctx[:stdout].string)
  end

  # -----------------------------------------------------------------------
  # 9. --json output passes JSON.parse and has correct shape
  # -----------------------------------------------------------------------
  def test_json_flag_produces_parseable_output
    git = fake_git
    ctx = run_command(argv: ["--message", "Add feature", "--json"], git: git)
    ctx[:cmd].run

    parsed = JSON.parse(ctx[:stdout].string)
    assert_equal "commit-apply", parsed["command"]
    assert_kind_of Array, parsed["actions_taken"]
    assert_kind_of Array, parsed["warnings"]
    assert_kind_of Hash, parsed["context"]
  end

  def test_json_flag_includes_commit_action_with_sha
    git = fake_git
    ctx = run_command(argv: ["--message", "Add feature", "--json"], git: git)
    ctx[:cmd].run

    parsed = JSON.parse(ctx[:stdout].string)
    commit_action = parsed["actions_taken"].find { |a| a["kind"] == "commit" }
    refute_nil commit_action
    assert_equal "abc1234", commit_action["details"]["sha"]
  end

  def test_json_flag_includes_message_first_line_in_action_details
    git = fake_git
    ctx = run_command(argv: ["--message", "Add feature\n\nMore detail", "--json"], git: git)
    ctx[:cmd].run

    parsed = JSON.parse(ctx[:stdout].string)
    commit_action = parsed["actions_taken"].find { |a| a["kind"] == "commit" }
    assert_equal "Add feature", commit_action["details"]["message_first_line"]
  end

  def test_json_flag_includes_context_flags
    git = fake_git
    ctx = run_command(argv: ["--message", "fix", "--json"], git: git)
    ctx[:cmd].run

    parsed = JSON.parse(ctx[:stdout].string)
    assert parsed["context"].key?("had_staged_changes")
    assert parsed["context"].key?("had_unstaged_changes")
  end

  def test_json_exit_1_when_no_staged_changes
    git = fake_git(staged_diff: "")
    out = StringIO.new
    err = StringIO.new
    cmd = GitContext::CommitApply.new(
      git: git, argv: ["--message", "fix", "--json"], stdin: StringIO.new, stdout: out, stderr: err
    )
    begin
      cmd.run
    rescue SystemExit => e
      assert_equal 1, e.status
    end
    # JSON still emitted to stdout on early exit
    parsed = JSON.parse(out.string)
    assert_equal 1, parsed["exit_code"]
  end
end

# ---------------------------------------------------------------------------
# CLI integration: commit-apply is wired (no longer a NotImplementedError stub)
# ---------------------------------------------------------------------------
class CLICommitApplyDispatchTest < Minitest::Test
  def test_commit_apply_missing_message_exits_2
    err = StringIO.new
    exit_status = nil
    begin
      GitContext::CLI.new(argv: ["commit-apply"], stdout: StringIO.new, stderr: err).run
    rescue SystemExit => e
      exit_status = e.status
    end
    assert_equal 2, exit_status
    assert_match(/message/i, err.string)
  end
end
