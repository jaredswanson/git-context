# frozen_string_literal: true

require "test_helper"
require "json"

class JsonReportTest < Minitest::Test
  def test_empty_report_produces_contract_shaped_hash
    report = GitContext::JsonReport.new(command: "test-cmd")

    result = report.to_h

    assert_equal "test-cmd", result["command"]
    assert_equal GitContext::VERSION, result["version"]
    assert_equal 0, result["exit_code"]
    assert_equal [], result["actions_taken"]
    assert_equal [], result["proposals"]
    assert_equal({}, result["context"])
    assert_equal [], result["warnings"]
  end

  def test_add_action_serializes_correctly
    report = GitContext::JsonReport.new(command: "test-cmd")
    report.add_action(kind: "file_created", description: "Created config.yml")

    result = report.to_h

    assert_equal 1, result["actions_taken"].length
    action = result["actions_taken"].first
    assert_equal "file_created", action["kind"]
    assert_equal "Created config.yml", action["description"]
    assert_equal({}, action["details"])
  end

  def test_add_action_with_details
    report = GitContext::JsonReport.new(command: "test-cmd")
    report.add_action(
      kind: "lint_fix",
      description: "Fixed style issues",
      details: { "files_fixed" => 5, "lines_changed" => 42 }
    )

    result = report.to_h
    action = result["actions_taken"].first

    assert_equal 5, action["details"]["files_fixed"]
    assert_equal 42, action["details"]["lines_changed"]
  end

  def test_add_proposal_serializes_correctly
    report = GitContext::JsonReport.new(command: "test-cmd")
    report.add_proposal(
      kind: "refactor",
      description: "Extract service layer",
      suggested_command: "bin/refactor --service"
    )

    result = report.to_h

    assert_equal 1, result["proposals"].length
    proposal = result["proposals"].first
    assert_equal "refactor", proposal["kind"]
    assert_equal "Extract service layer", proposal["description"]
    assert_equal "bin/refactor --service", proposal["suggested_command"]
    assert_equal({}, proposal["details"])
  end

  def test_add_proposal_with_details
    report = GitContext::JsonReport.new(command: "test-cmd")
    report.add_proposal(
      kind: "config",
      description: "Update API keys",
      details: { "env_vars" => ["API_KEY", "SECRET"] }
    )

    result = report.to_h
    proposal = result["proposals"].first

    assert_equal(["API_KEY", "SECRET"], proposal["details"]["env_vars"])
  end

  def test_add_warning_serializes_correctly
    report = GitContext::JsonReport.new(command: "test-cmd")
    report.add_warning(kind: "deprecation", description: "Old API endpoint in use")

    result = report.to_h

    assert_equal 1, result["warnings"].length
    warning = result["warnings"].first
    assert_equal "deprecation", warning["kind"]
    assert_equal "Old API endpoint in use", warning["description"]
  end

  def test_set_context_replaces_entire_context
    report = GitContext::JsonReport.new(command: "test-cmd")
    report.set_context({ "foo" => "bar" })
    report.set_context({ "baz" => "qux" })

    result = report.to_h

    assert_equal({ "baz" => "qux" }, result["context"])
  end

  def test_merge_context_merges_into_existing_context
    report = GitContext::JsonReport.new(command: "test-cmd")
    report.set_context({ "foo" => "bar" })
    report.merge_context({ "baz" => "qux" })

    result = report.to_h

    assert_equal({ "foo" => "bar", "baz" => "qux" }, result["context"])
  end

  def test_fail_sets_exit_code
    report = GitContext::JsonReport.new(command: "test-cmd")
    report.fail!(1)

    result = report.to_h

    assert_equal 1, result["exit_code"]
  end

  def test_fail_with_different_codes
    report = GitContext::JsonReport.new(command: "test-cmd")
    report.fail!(42)

    result = report.to_h

    assert_equal 42, result["exit_code"]
  end

  def test_to_json_serializes_to_valid_json
    report = GitContext::JsonReport.new(command: "test-cmd", version: "1.0.0")
    report.add_action(kind: "test", description: "Test action")
    report.set_context({ "key" => "value" })

    json_str = report.to_json

    parsed = JSON.parse(json_str)
    assert_equal "test-cmd", parsed["command"]
    assert_equal "1.0.0", parsed["version"]
    assert_equal 1, parsed["actions_taken"].length
    assert_equal({ "key" => "value" }, parsed["context"])
  end

  def test_to_json_pretty_formats_output
    report = GitContext::JsonReport.new(command: "test-cmd")
    report.add_action(kind: "test", description: "Test")

    pretty_json = report.to_json(pretty: true)

    assert_includes pretty_json, "\n"
    assert_includes pretty_json, "  "
  end

  def test_to_json_default_is_compact
    report = GitContext::JsonReport.new(command: "test-cmd")
    report.add_action(kind: "test", description: "Test")

    compact_json = report.to_json(pretty: false)

    lines = compact_json.strip.split("\n")
    assert lines.length <= 2, "Compact JSON should be mostly on one line"
  end

  def test_custom_version
    report = GitContext::JsonReport.new(command: "test-cmd", version: "2.0.0")

    result = report.to_h

    assert_equal "2.0.0", result["version"]
  end

  def test_version_defaults_to_git_context_version
    report = GitContext::JsonReport.new(command: "test-cmd")

    result = report.to_h

    assert_equal GitContext::VERSION, result["version"]
  end

  def test_multiple_actions_proposals_warnings
    report = GitContext::JsonReport.new(command: "test-cmd")
    report.add_action(kind: "act1", description: "Action 1")
    report.add_action(kind: "act2", description: "Action 2")
    report.add_proposal(kind: "prop1", description: "Proposal 1")
    report.add_warning(kind: "warn1", description: "Warning 1")

    result = report.to_h

    assert_equal 2, result["actions_taken"].length
    assert_equal 1, result["proposals"].length
    assert_equal 1, result["warnings"].length
  end

  def test_to_json_parses_back_to_equivalent_hash
    report = GitContext::JsonReport.new(command: "test-cmd")
    report.add_action(kind: "test", description: "Test action", details: { "count" => 5 })
    report.add_proposal(kind: "suggest", description: "Suggested", suggested_command: "run-this")
    report.set_context({ "git_branch" => "main" })
    report.fail!(2)

    original_hash = report.to_h
    json_str = report.to_json
    parsed_hash = JSON.parse(json_str)

    assert_equal original_hash, parsed_hash
  end
end
