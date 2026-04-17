# frozen_string_literal: true

require "test_helper"

class TruncatedDiffTest < Minitest::Test
  def test_passes_through_diff_under_limit
    raw = <<~DIFF
      diff --git a/a.rb b/a.rb
      index 111..222 100644
      --- a/a.rb
      +++ b/a.rb
      @@ -1,1 +1,1 @@
      -old
      +new
    DIFF

    assert_equal raw, GitContext::TruncatedDiff.new(raw, max_lines_per_file: 50).to_s
  end

  def test_truncates_large_single_file_diff
    body_lines = (1..100).map { |i| "+line #{i}" }
    raw = (["diff --git a/big.rb b/big.rb", "--- a/big.rb", "+++ b/big.rb", "@@ -0,0 +1,100 @@"] + body_lines).join("\n") + "\n"

    out = GitContext::TruncatedDiff.new(raw, max_lines_per_file: 10).to_s

    assert_includes out, "+line 1"
    assert_includes out, "+line 10"
    refute_includes out, "+line 11"
    assert_includes out, "... 90 more lines truncated"
  end

  def test_truncates_each_file_independently
    file_a = ["diff --git a/a.rb b/a.rb", "--- a/a.rb", "+++ b/a.rb", "@@ -0,0 +1,20 @@"] + (1..20).map { |i| "+a#{i}" }
    file_b = ["diff --git a/b.rb b/b.rb", "--- a/b.rb", "+++ b/b.rb", "@@ -0,0 +1,20 @@"] + (1..20).map { |i| "+b#{i}" }
    raw = (file_a + file_b).join("\n") + "\n"

    out = GitContext::TruncatedDiff.new(raw, max_lines_per_file: 5).to_s

    assert_includes out, "+a1"
    assert_includes out, "+a5"
    refute_includes out, "+a6"
    assert_includes out, "+b1"
    assert_includes out, "+b5"
    refute_includes out, "+b6"
    assert_equal 2, out.scan("more lines truncated").length
  end

  def test_empty_diff_returns_empty_string
    assert_equal "", GitContext::TruncatedDiff.new("", max_lines_per_file: 50).to_s
  end
end
