# frozen_string_literal: true

require "test_helper"

class StatusSectionTest < Minitest::Test
  def test_renders_git_status_output
    git = FakeGit.new(status: "?? foo.rb\n M bar.rb\n")
    section = CommitContext::Sections::Status.new

    assert_equal "Status", section.title
    assert_includes section.render(git), "?? foo.rb"
    assert_includes section.render(git), " M bar.rb"
  end

  def test_renders_clean_marker_when_empty
    section = CommitContext::Sections::Status.new
    assert_equal "(clean)", section.render(FakeGit.new(status: "")).strip
  end
end

class StagedDiffSectionTest < Minitest::Test
  def test_renders_staged_diff_truncated
    git = FakeGit.new(staged_diff: fake_diff("a.rb", 50))
    section = CommitContext::Sections::StagedDiff.new(max_lines_per_file: 5)

    out = section.render(git)

    assert_equal "Staged changes", section.title
    assert_includes out, "+line1"
    assert_includes out, "more lines truncated"
  end

  def test_none_marker_when_empty
    section = CommitContext::Sections::StagedDiff.new(max_lines_per_file: 5)
    assert_equal "(none)", section.render(FakeGit.new).strip
  end

  private

  def fake_diff(path, n)
    header = "diff --git a/#{path} b/#{path}\n--- a/#{path}\n+++ b/#{path}\n@@ -0,0 +1,#{n} @@\n"
    header + (1..n).map { |i| "+line#{i}\n" }.join
  end
end

class UnstagedDiffSectionTest < Minitest::Test
  def test_uses_unstaged_diff
    git = FakeGit.new(unstaged_diff: "diff --git a/x b/x\n--- a/x\n+++ b/x\n@@ -1 +1 @@\n-a\n+b\n")
    section = CommitContext::Sections::UnstagedDiff.new(max_lines_per_file: 100)

    assert_equal "Unstaged changes", section.title
    assert_includes section.render(git), "+b"
  end
end

class RecentLogSectionTest < Minitest::Test
  def test_shows_recent_commits
    git = FakeGit.new(recent_log: "abc123 first\ndef456 second\n")
    section = CommitContext::Sections::RecentLog.new(limit: 5)

    assert_equal "Recent commits", section.title
    assert_includes section.render(git), "abc123 first"
  end
end

class FileHistorySectionTest < Minitest::Test
  def test_shows_recent_history_per_modified_file
    git = FakeGit.new(
      modified_files: ["a.rb", "b.rb"],
      file_logs: { "a.rb" => "aaa added a\n", "b.rb" => "bbb fixed b\n" }
    )
    section = CommitContext::Sections::FileHistory.new(limit: 3)

    out = section.render(git)

    assert_equal "Recent history of modified files", section.title
    assert_includes out, "a.rb"
    assert_includes out, "aaa added a"
    assert_includes out, "b.rb"
    assert_includes out, "bbb fixed b"
  end

  def test_empty_when_no_modified_files
    section = CommitContext::Sections::FileHistory.new(limit: 3)
    assert_equal "(none)", section.render(FakeGit.new).strip
  end
end

class UntrackedFilesSectionTest < Minitest::Test
  def test_lists_untracked_files_with_contents
    git = FakeGit.new(
      untracked_files: ["new.rb"],
      file_contents: { "new.rb" => "hello world\n" }
    )
    section = CommitContext::Sections::UntrackedFiles.new

    out = section.render(git)

    assert_equal "Untracked files", section.title
    assert_includes out, "new.rb"
    assert_includes out, "hello world"
  end

  def test_none_marker_when_no_untracked
    section = CommitContext::Sections::UntrackedFiles.new
    assert_equal "(none)", section.render(FakeGit.new).strip
  end
end
