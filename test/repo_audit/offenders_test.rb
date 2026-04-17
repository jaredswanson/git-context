# frozen_string_literal: true

require "test_helper"

class OffendersTest < Minitest::Test
  def test_all_patterns_is_nonempty_and_frozen
    assert_kind_of Array, GitContext::RepoAudit::Offenders.all_patterns
    refute_empty GitContext::RepoAudit::Offenders.all_patterns
    assert GitContext::RepoAudit::Offenders.all_patterns.frozen?
  end

  def test_categories_are_grouped
    cats = GitContext::RepoAudit::Offenders::CATEGORIES
    assert cats.key?(:env_files)
    assert_includes cats[:env_files], ".env"
  end

  def test_secret_patterns_include_pem_and_rsa
    patterns = GitContext::RepoAudit::Offenders::SECRET_PATTERNS
    assert_includes patterns, "*.pem"
    assert_includes patterns, "id_rsa*"
  end

  def test_matches_handles_directory_prefix
    assert GitContext::RepoAudit::Offenders.matches?("node_modules/x/y.js", "node_modules/")
    refute GitContext::RepoAudit::Offenders.matches?("src/node_modules_like.js", "node_modules/")
  end

  def test_matches_handles_glob
    assert GitContext::RepoAudit::Offenders.matches?("errors.log", "*.log")
    assert GitContext::RepoAudit::Offenders.matches?("foo/bar/baz.log", "*.log")
    refute GitContext::RepoAudit::Offenders.matches?("foo/bar/baz.txt", "*.log")
  end

  def test_matches_handles_plain_basename
    assert GitContext::RepoAudit::Offenders.matches?(".env", ".env")
    assert GitContext::RepoAudit::Offenders.matches?("config/.env", ".env")
    refute GitContext::RepoAudit::Offenders.matches?(".envrc", ".env")
  end
end
