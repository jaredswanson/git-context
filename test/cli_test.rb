# frozen_string_literal: true

require "test_helper"

class CLITest < Minitest::Test
  include TempRepo

  def test_runs_commit_preset_by_default_tokens_against_repo_flag
    in_temp_repo do |dir|
      write_file("a.rb", "hi")
      git("add a.rb")

      out = StringIO.new
      GitContext::CLI.new(argv: ["commit", "--repo", dir], stdout: out).run

      assert_match(/## Status/, out.string)
      assert_match(/## Staged changes/, out.string)
    end
  end

  def test_only_flag_restricts_sections
    in_temp_repo do |dir|
      out = StringIO.new
      GitContext::CLI.new(argv: ["commit", "--repo", dir, "--only", "status"], stdout: out).run

      assert_match(/## Status/, out.string)
      refute_match(/## Staged changes/, out.string)
    end
  end

  def test_skip_flag_removes_sections
    in_temp_repo do |dir|
      out = StringIO.new
      GitContext::CLI.new(
        argv: ["commit", "--repo", dir, "--skip", "staged_diff,unstaged_diff"],
        stdout: out
      ).run

      assert_match(/## Status/, out.string)
      refute_match(/## Staged changes/, out.string)
      refute_match(/## Unstaged changes/, out.string)
    end
  end

  def test_add_flag_is_additive
    in_temp_repo do |dir|
      out = StringIO.new
      GitContext::CLI.new(
        argv: ["commit", "--repo", dir, "--add", "status"],
        stdout: out
      ).run

      assert_equal 1, out.string.scan(/^## Status$/).size
    end
  end

  def test_list_sections_prints_tokens_and_exits
    out = StringIO.new
    GitContext::CLI.new(argv: ["commit", "--list-sections"], stdout: out).run

    GitContext::Commit::Preset.new.available_tokens.each do |token|
      assert_match(/^#{Regexp.escape(token)}$/, out.string)
    end
  end

  def test_unknown_preset_errors_with_suggestion
    err = StringIO.new
    assert_raises(SystemExit) do
      GitContext::CLI.new(argv: ["bogus"], stdout: StringIO.new, stderr: err).run
    end
    assert_match(/unknown preset 'bogus'/, err.string)
    assert_match(/Available: commit/, err.string)
  end

  def test_unknown_section_errors_with_suggestion
    err = StringIO.new
    assert_raises(SystemExit) do
      GitContext::CLI.new(
        argv: ["commit", "--only", "bogus"], stdout: StringIO.new, stderr: err
      ).run
    end
    assert_match(/unknown section 'bogus'/, err.string)
  end

  def test_missing_preset_arg_prints_help_and_exits
    err = StringIO.new
    assert_raises(SystemExit) do
      GitContext::CLI.new(argv: [], stdout: StringIO.new, stderr: err).run
    end
    assert_match(/Usage:/, err.string)
  end
end

class CLIRepoAuditTest < Minitest::Test
  include TempRepo

  def test_runs_repo_audit_preset
    in_temp_repo do |dir|
      write_file(".env", "x")

      out = StringIO.new
      GitContext::CLI.new(argv: ["repo-audit", "--repo", dir], stdout: out).run

      assert_match(/## Gitignore gaps/, out.string)
      assert_match(/## Tracked secrets/, out.string)
      assert_match(/## Missing standard files/, out.string)
      assert_match(/\.env/, out.string)
    end
  end

  def test_repo_audit_list_sections
    out = StringIO.new
    GitContext::CLI.new(argv: ["repo-audit", "--list-sections"], stdout: out).run

    assert_match(/gitignore_gaps/, out.string)
    assert_match(/tracked_secrets/, out.string)
    assert_match(/missing_standard_files/, out.string)
  end
end
