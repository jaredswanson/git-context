# frozen_string_literal: true

require "test_helper"

class CommitPresetTest < Minitest::Test
  def test_name_is_commit
    assert_equal "commit", GitContext::Commit::Preset.new.name
  end

  def test_sections_returns_instances_for_default_tokens
    preset = GitContext::Commit::Preset.new
    sections = preset.sections

    assert_equal preset.default_tokens.size, sections.size
    sections.each { |s| assert_respond_to s, :title }
    sections.each { |s| assert_respond_to s, :render }
  end

  def test_sections_with_explicit_tokens_returns_only_those
    preset = GitContext::Commit::Preset.new
    sections = preset.sections(%w[status recent_log])

    assert_equal 2, sections.size
    assert_instance_of GitContext::Commit::Sections::Status, sections[0]
    assert_instance_of GitContext::Commit::Sections::RecentLog, sections[1]
  end

  def test_section_for_unknown_token_raises_with_suggestion
    preset = GitContext::Commit::Preset.new
    err = assert_raises(ArgumentError) { preset.section_for("bogus") }
    assert_match(/unknown section 'bogus'/, err.message)
    assert_match(/Available:/, err.message)
  end

  def test_available_tokens_includes_all_defaults
    preset = GitContext::Commit::Preset.new
    assert_empty(preset.default_tokens - preset.available_tokens)
  end
end
