# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "minitest/autorun"
require "tmpdir"
require "fileutils"
require "git_context"

# Fake Git implementing the methods sections depend on. Shared across tests.
class FakeGit
  def initialize(**canned)
    @canned = canned
    @file_logs = canned[:file_logs] || {}
  end

  def status; @canned[:status] || ""; end
  def diff(staged:); (staged ? @canned[:staged_diff] : @canned[:unstaged_diff]) || ""; end
  def recent_log(limit:); @canned[:recent_log] || ""; end
  def modified_files; @canned[:modified_files] || []; end
  def untracked_files; @canned[:untracked_files] || []; end
  def file_log(path, limit:); @file_logs.fetch(path, ""); end
  def read_file(path); (@canned[:file_contents] || {}).fetch(path, ""); end
end

module TempRepo
  def in_temp_repo
    Dir.mktmpdir("git_context_test") do |dir|
      Dir.chdir(dir) do
        system("git init -q -b main", exception: true)
        system("git config user.email test@example.com", exception: true)
        system("git config user.name Test", exception: true)
        yield dir
      end
    end
  end

  def write_file(path, contents)
    FileUtils.mkdir_p(File.dirname(path)) unless File.dirname(path) == "."
    File.write(path, contents)
  end

  def git(cmd)
    system("git #{cmd}", exception: true, out: File::NULL, err: File::NULL)
  end
end
