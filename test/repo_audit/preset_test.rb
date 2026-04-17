# frozen_string_literal: true

require "test_helper"

class RepoAuditPresetTest < Minitest::Test
  def test_name_is_repo_audit
    assert_equal "repo-audit", GitContext::RepoAudit::Preset.new.name
  end

  def test_default_tokens_cover_all_three_sections
    preset = GitContext::RepoAudit::Preset.new
    assert_equal %w[gitignore_gaps tracked_secrets missing_standard_files].sort,
                 preset.default_tokens.sort
  end

  def test_sections_returns_instances
    sections = GitContext::RepoAudit::Preset.new.sections
    assert_equal 3, sections.size
    sections.each { |s| assert_respond_to s, :title }
    sections.each { |s| assert_respond_to s, :render }
  end

  def test_unknown_token_raises
    assert_raises(ArgumentError) { GitContext::RepoAudit::Preset.new.section_for("bogus") }
  end
end
