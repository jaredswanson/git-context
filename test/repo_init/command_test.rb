# frozen_string_literal: true

require "test_helper"
require "json"

class RepoInitCommandTest < Minitest::Test
  def build(argv:, git: nil, workspace: nil)
    git ||= FakeGit.new(entries: { "." => ["foo.gemspec"] })
    workspace ||= FakeWorkspace.new
    stdout = StringIO.new
    stderr = StringIO.new
    cmd = GitContext::RepoInit::Command.new(
      git: git,
      workspace: workspace,
      argv: argv,
      stdout: stdout,
      stderr: stderr
    )
    { cmd: cmd, git: git, workspace: workspace, stdout: stdout, stderr: stderr }
  end

  def json_from(stdout)
    JSON.parse(stdout.string)
  end

  # 1. Brand-new ruby-gem repo
  def test_brand_new_ruby_gem_repo_emits_all_bootstrap_actions
    git = FakeGit.new(
      entries: { "." => ["foo.gemspec"] },
      has_commits: false,
      config: { "user.name" => "Alice" }
    )
    ctx = build(argv: ["--json"], git: git)

    ctx[:cmd].run

    report = json_from(ctx[:stdout])
    kinds = report["actions_taken"].map { |a| a["kind"] }
    assert_includes kinds, "git_init"
    assert_includes kinds, "gitignore_append"
    assert_includes kinds, "initial_commit"
    assert_includes kinds, "license_created"
  end

  def test_brand_new_repo_records_detected_stack_context
    git = FakeGit.new(entries: { "." => ["foo.gemspec"] })
    ctx = build(argv: ["--json"], git: git)

    ctx[:cmd].run

    report = json_from(ctx[:stdout])
    assert_equal "ruby_gem", report["context"]["stack"]
    assert_includes report["context"]["detected_stacks"], "ruby_gem"
  end

  # 2. Propose remote when origin absent
  def test_proposes_remote_when_origin_absent
    git = FakeGit.new(entries: { "." => ["foo.gemspec"] })
    ctx = build(argv: ["--json"], git: git)

    ctx[:cmd].run

    report = json_from(ctx[:stdout])
    kinds = report["proposals"].map { |p| p["kind"] }
    assert_includes kinds, "create_remote"
  end

  # 3. Idempotency
  def test_idempotent_second_run_only_proposes_remote
    workspace = FakeWorkspace.new(
      files: {
        ".git" => [],
        ".gitignore" => GitContext::RepoInit::GitignorePatterns::RUBY_GEM.map { |p| "#{p}\n" },
        "LICENSE" => "existing license\n"
      }
    )
    git = FakeGit.new(
      entries: { "." => ["foo.gemspec"] },
      has_commits: true,
      remotes: []
    )
    ctx = build(argv: ["--json"], git: git, workspace: workspace)

    ctx[:cmd].run

    report = json_from(ctx[:stdout])
    assert_empty report["actions_taken"]
    kinds = report["proposals"].map { |p| p["kind"] }
    assert_includes kinds, "create_remote"
  end

  # 4. Dry-run: no actions, proposals instead
  def test_dry_run_emits_proposals_not_actions
    git = FakeGit.new(entries: { "." => ["foo.gemspec"] })
    ctx = build(argv: ["--json", "--dry-run"], git: git)

    ctx[:cmd].run

    report = json_from(ctx[:stdout])
    assert_empty report["actions_taken"]
    proposal_kinds = report["proposals"].map { |p| p["kind"] }
    assert_includes proposal_kinds, "git_init"
    assert_includes proposal_kinds, "gitignore_append"
  end

  def test_dry_run_does_not_invoke_git_writes
    git = FakeGit.new(entries: { "." => ["foo.gemspec"] })
    ctx = build(argv: ["--dry-run", "--json"], git: git)

    ctx[:cmd].run

    call_kinds = git.calls.map(&:first)
    refute_includes call_kinds, :init_repo
    refute_includes call_kinds, :commit
  end

  # 5. --yes with canned gh success: proposal moves to actions_taken
  def test_yes_with_successful_gh_moves_remote_to_actions_taken
    git = FakeGit.new(entries: { "." => ["foo.gemspec"] })
    workspace = FakeWorkspace.new(
      gh_results: Hash.new(GitContext::Workspace::Result.new(success?: true, output: "", error: ""))
    )
    ctx = build(argv: ["--json", "--yes", "--host", "github", "--visibility", "public"],
                git: git, workspace: workspace)

    ctx[:cmd].run

    report = json_from(ctx[:stdout])
    kinds = report["actions_taken"].map { |a| a["kind"] }
    assert_includes kinds, "remote_created"
  end

  # 6. private + forgejo overrides heuristic: no license action
  def test_private_forgejo_overrides_heuristic
    git = FakeGit.new(entries: { "." => ["foo.gemspec"] })
    ctx = build(argv: ["--json", "--visibility", "private", "--host", "forgejo"], git: git)

    ctx[:cmd].run

    report = json_from(ctx[:stdout])
    action_kinds = report["actions_taken"].map { |a| a["kind"] }
    refute_includes action_kinds, "license_created"

    remote_proposals = report["proposals"].select { |p| p["kind"] == "create_remote" }
    assert_equal 1, remote_proposals.length
    assert_match(/tea/, remote_proposals.first["suggested_command"])
  end

  # 7. Existing LICENSE: replace_license proposal
  def test_existing_license_proposes_replace_license
    workspace = FakeWorkspace.new(files: { "LICENSE" => "existing\n", ".git" => [] })
    git = FakeGit.new(entries: { "." => ["foo.gemspec"] }, has_commits: true)
    ctx = build(argv: ["--json"], git: git, workspace: workspace)

    ctx[:cmd].run

    report = json_from(ctx[:stdout])
    kinds = report["proposals"].map { |p| p["kind"] }
    assert_includes kinds, "replace_license"
    action_kinds = report["actions_taken"].map { |a| a["kind"] }
    refute_includes action_kinds, "license_created"
  end

  # 8. Existing .gitignore with some patterns
  def test_gitignore_only_appends_missing_patterns
    existing = ["*.gem\n", "/pkg/\n"]
    workspace = FakeWorkspace.new(files: { ".git" => [], ".gitignore" => existing })
    git = FakeGit.new(entries: { "." => ["foo.gemspec"] }, has_commits: true)
    ctx = build(argv: ["--json"], git: git, workspace: workspace)

    ctx[:cmd].run

    report = json_from(ctx[:stdout])
    action = report["actions_taken"].find { |a| a["kind"] == "gitignore_append" }
    assert action, "expected gitignore_append action"
    skipped = action["details"]["patterns_skipped"]
    added = action["details"]["patterns_added"]
    assert_includes skipped, "*.gem"
    assert_includes skipped, "/pkg/"
    refute_includes added, "*.gem"
    assert_includes added, "/doc/"
  end

  def test_help_flag_prints_help_and_returns
    git = FakeGit.new(entries: { "." => [] })
    ctx = build(argv: ["--help"], git: git)

    ctx[:cmd].run

    assert_match(/Usage: git-context repo-init/, ctx[:stdout].string)
  end

  def test_non_json_mode_emits_human_readable_output
    git = FakeGit.new(entries: { "." => ["foo.gemspec"] })
    ctx = build(argv: [], git: git)

    ctx[:cmd].run

    out = ctx[:stdout].string
    assert_match(/Actions taken/i, out)
    assert_match(/Proposals/i, out)
  end
end
