# frozen_string_literal: true

require "test_helper"
require "git_context/repo_audit/sections/tracked_secrets"

class TrackedSecretsSectionTest < Minitest::Test
  include TempRepo

  def test_title
    assert_equal "Tracked secrets", GitContext::RepoAudit::Sections::TrackedSecrets.new.title
  end

  def test_flags_tracked_env_file
    in_temp_repo do |dir|
      write_file(".env", "SECRET=1")
      write_file("app.rb", "x")
      git("add -A")
      git("commit -q -m init")

      out = GitContext::RepoAudit::Sections::TrackedSecrets.new.render(GitContext::Git.new(dir))
      assert_match(/\.env/, out)
      refute_match(/app\.rb/, out)
      assert_match(/git rm --cached/, out)
    end
  end

  def test_flags_tracked_pem_file
    in_temp_repo do |dir|
      write_file("cert.pem", "x")
      git("add cert.pem")
      git("commit -q -m init")

      out = GitContext::RepoAudit::Sections::TrackedSecrets.new.render(GitContext::Git.new(dir))
      assert_match(/cert\.pem/, out)
    end
  end

  def test_none_marker_when_nothing_flagged
    in_temp_repo do |dir|
      write_file("app.rb", "x")
      git("add app.rb")
      git("commit -q -m init")

      out = GitContext::RepoAudit::Sections::TrackedSecrets.new.render(GitContext::Git.new(dir))
      assert_match(/No tracked secrets/, out)
    end
  end

  def test_empty_repo_returns_none
    in_temp_repo do |dir|
      out = GitContext::RepoAudit::Sections::TrackedSecrets.new.render(GitContext::Git.new(dir))
      assert_match(/No tracked secrets/, out)
    end
  end

  def test_does_not_flag_own_source_files
    git = FakeGit.new(ls_files: [
      "lib/git_context/repo_audit/sections/tracked_secrets.rb",
      "test/repo_audit/sections/tracked_secrets_test.rb"
    ])

    out = GitContext::RepoAudit::Sections::TrackedSecrets.new.render(git)

    assert_match(/No tracked secrets/, out)
  end

  def test_flags_secrets_yml
    git = FakeGit.new(ls_files: ["config/secrets.yml"])

    out = GitContext::RepoAudit::Sections::TrackedSecrets.new.render(git)

    assert_match(/secrets\.yml/, out)
  end

  def test_flags_credentials_json
    git = FakeGit.new(ls_files: ["app.credentials.json"])

    out = GitContext::RepoAudit::Sections::TrackedSecrets.new.render(git)

    assert_match(/app\.credentials\.json/, out)
  end
end
