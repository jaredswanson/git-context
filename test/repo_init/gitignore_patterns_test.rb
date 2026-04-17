# frozen_string_literal: true

require "test_helper"

class GitignorePatternsTest < Minitest::Test
  def test_for_ruby_gem_returns_array_containing_gem_extension
    patterns = GitContext::RepoInit::GitignorePatterns.for(:ruby_gem)

    assert_kind_of Array, patterns
    assert_includes patterns, "*.gem"
  end

  def test_for_node_returns_array_containing_node_modules
    patterns = GitContext::RepoInit::GitignorePatterns.for(:node)

    assert_includes patterns, "node_modules/"
  end

  def test_for_python_returns_array_containing_pycache
    patterns = GitContext::RepoInit::GitignorePatterns.for(:python)

    assert_includes patterns, "__pycache__/"
  end

  def test_for_claude_plugin_returns_array_containing_local_settings
    patterns = GitContext::RepoInit::GitignorePatterns.for(:claude_plugin)

    assert_includes patterns, ".claude/local-settings.json"
  end

  def test_for_generic_returns_array_containing_ds_store
    patterns = GitContext::RepoInit::GitignorePatterns.for(:generic)

    assert_includes patterns, ".DS_Store"
  end

  def test_merged_returns_deduped_union_of_stacks
    patterns = GitContext::RepoInit::GitignorePatterns.merged([:ruby_gem, :generic])

    assert_includes patterns, "*.gem"
    assert_includes patterns, ".DS_Store"
    assert_equal patterns.uniq, patterns
  end

  def test_merged_deduplicates_overlapping_entries
    # Inject a duplicate by merging the same stack twice
    patterns = GitContext::RepoInit::GitignorePatterns.merged([:ruby_gem, :ruby_gem])

    assert_equal patterns.uniq, patterns
  end

  def test_for_unknown_stack_returns_empty_array
    patterns = GitContext::RepoInit::GitignorePatterns.for(:unknown_stack)

    assert_equal [], patterns
  end
end
