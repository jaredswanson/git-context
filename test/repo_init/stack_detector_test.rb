# frozen_string_literal: true

require "test_helper"

class StackDetectorTest < Minitest::Test
  def make_git(root_entries: [], file_contents: {})
    FakeGit.new(
      entries: { "." => root_entries },
      file_contents: file_contents
    )
  end

  # --- stack detection ---

  def test_detects_ruby_gem_from_gemspec
    git = make_git(root_entries: ["foo.gemspec", "lib", "Rakefile"])

    stacks = GitContext::RepoInit::StackDetector.new(git: git).stacks

    assert_includes stacks, :ruby_gem
  end

  def test_detects_claude_plugin_from_dot_claude_plugin_dir
    git = make_git(root_entries: [".claude-plugin", "README.md"])

    stacks = GitContext::RepoInit::StackDetector.new(git: git).stacks

    assert_includes stacks, :claude_plugin
  end

  def test_detects_node_from_package_json
    git = make_git(root_entries: ["package.json", "src"])

    stacks = GitContext::RepoInit::StackDetector.new(git: git).stacks

    assert_includes stacks, :node
  end

  def test_detects_python_from_pyproject_toml
    git = make_git(root_entries: ["pyproject.toml", "src"])

    stacks = GitContext::RepoInit::StackDetector.new(git: git).stacks

    assert_includes stacks, :python
  end

  def test_detects_python_from_setup_py
    git = make_git(root_entries: ["setup.py", "src"])

    stacks = GitContext::RepoInit::StackDetector.new(git: git).stacks

    assert_includes stacks, :python
  end

  def test_falls_back_to_generic_when_no_known_stack
    git = make_git(root_entries: ["README.md", "Makefile"])

    stacks = GitContext::RepoInit::StackDetector.new(git: git).stacks

    assert_equal [:generic], stacks
  end

  def test_detects_multiple_stacks_gem_and_claude_plugin
    git = make_git(root_entries: ["my.gemspec", ".claude-plugin", "lib"])

    stacks = GitContext::RepoInit::StackDetector.new(git: git).stacks

    assert_includes stacks, :ruby_gem
    assert_includes stacks, :claude_plugin
    refute_includes stacks, :generic
  end

  def test_detection_order_ruby_gem_before_claude_plugin
    git = make_git(root_entries: ["my.gemspec", ".claude-plugin"])

    stacks = GitContext::RepoInit::StackDetector.new(git: git).stacks

    assert_equal [:ruby_gem, :claude_plugin], stacks
  end

  # --- likely_open_source? ---

  def test_open_source_true_when_gemspec_present
    git = make_git(root_entries: ["my.gemspec"])

    result = GitContext::RepoInit::StackDetector.new(git: git).likely_open_source?

    assert result.value
    assert_includes result.signals, "gemspec present"
  end

  def test_open_source_true_when_claude_plugin_manifest_present
    git = make_git(root_entries: [".claude-plugin"])

    result = GitContext::RepoInit::StackDetector.new(git: git).likely_open_source?

    assert result.value
    assert_includes result.signals, ".claude-plugin manifest present"
  end

  def test_open_source_true_when_package_json_has_no_private_key
    json = '{"name":"my-pkg","version":"1.0.0"}'
    git = make_git(root_entries: ["package.json"], file_contents: { "package.json" => json })

    result = GitContext::RepoInit::StackDetector.new(git: git).likely_open_source?

    assert result.value
    assert_includes result.signals, "package.json without private:true"
  end

  def test_open_source_true_when_package_json_private_is_false
    json = '{"name":"my-pkg","private":false}'
    git = make_git(root_entries: ["package.json"], file_contents: { "package.json" => json })

    result = GitContext::RepoInit::StackDetector.new(git: git).likely_open_source?

    assert result.value
    assert_includes result.signals, "package.json without private:true"
  end

  def test_open_source_false_when_package_json_private_is_true
    json = '{"name":"my-pkg","private":true}'
    git = make_git(root_entries: ["package.json"], file_contents: { "package.json" => json })

    result = GitContext::RepoInit::StackDetector.new(git: git).likely_open_source?

    refute result.value
    assert_empty result.signals
  end

  def test_open_source_false_when_no_signals
    git = make_git(root_entries: ["README.md"])

    result = GitContext::RepoInit::StackDetector.new(git: git).likely_open_source?

    refute result.value
    assert_empty result.signals
  end
end
