# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "minitest/autorun"
require "tmpdir"
require "fileutils"
require "stringio"
require "git_context"

# Fake Git implementing the methods sections depend on. Shared across tests.
class FakeGit
  attr_reader :calls

  def initialize(**canned)
    @canned = canned
    @file_logs = canned[:file_logs] || {}
    @calls = []
    @has_commits = canned.fetch(:has_commits, false)
    @remotes = (canned[:remotes] || []).dup
    @config = canned[:config] || { "user.name" => "Test User" }
  end

  def init_repo(branch: "main")
    @calls << [:init_repo, { branch: branch }]
    true
  end

  def add(path)
    @calls << [:add, path]
    true
  end

  def has_commits?
    @has_commits
  end

  def current_branch
    @canned[:current_branch] || "main"
  end

  def add_remote(name, url)
    @calls << [:add_remote, name, url]
    @remotes << name
    true
  end

  def has_remote?(name)
    @remotes.include?(name)
  end

  def config_get(key)
    @config[key]
  end

  def status; @canned[:status] || ""; end
  def diff(staged:); (staged ? @canned[:staged_diff] : @canned[:unstaged_diff]) || ""; end
  def recent_log(limit:); @canned[:recent_log] || ""; end
  def modified_files; @canned[:modified_files] || []; end
  def untracked_files; @canned[:untracked_files] || []; end
  def file_log(path, limit:); @file_logs.fetch(path, ""); end
  def read_file(path); (@canned[:file_contents] || {}).fetch(path, ""); end
  def ls_files; @canned[:ls_files] || []; end
  def walk_working_tree; @canned[:walk_working_tree] || []; end

  # Returns the direct children for the given subpath from a canned hash.
  # The hash maps subpath strings (e.g. ".", "lib") to arrays of entry names.
  def entries(subpath = ".")
    (@canned[:entries] || {})[subpath] || []
  end

  def ignored?(path)
    (@canned[:ignored] || {})[path] || false
  end

  # Records the committed message and returns a canned SHA. The recorded
  # messages array lets tests assert that commit was called with the right text.
  def commit(message)
    @commits ||= []
    @commits << message
    @calls << [:commit, message]
    @has_commits = true
    @canned[:commit_sha] || "abc1234"
  end

  def commits
    @commits || []
  end
end

# Test double for GitContext::Workspace. Downstream tasks use this instead of
# spinning up a real filesystem or shelling out to gh/tea.
class FakeWorkspace
  attr_reader :writes, :repo_path

  def initialize(files: {}, gh_results: {}, tea_results: {}, available_binaries: Hash.new(true), repo_path: "/tmp/fake-repo")
    @files = files.transform_values { |v| v.is_a?(Array) ? v : v.lines }
    @writes = {}
    @gh_results = gh_results
    @tea_results = tea_results
    @available_binaries = available_binaries
    @repo_path = repo_path
  end

  def write_file(relative_path, contents, mode: "w")
    existing = mode == "a" ? (@writes[relative_path] || "") : ""
    @writes[relative_path] = existing + contents
  end

  def append_file(relative_path, contents)
    write_file(relative_path, contents, mode: "a")
  end

  def file_exists?(relative_path)
    @files.key?(relative_path) || @writes.key?(relative_path)
  end

  def read_lines(relative_path)
    @files.fetch(relative_path, [])
  end

  def run_gh(*args)
    canned_result(@gh_results, args)
  end

  def run_tea(*args)
    canned_result(@tea_results, args)
  end

  def which(binary)
    @available_binaries[binary]
  end

  private

  def canned_result(map, args)
    key = args.join(" ")
    map.fetch(key) do
      GitContext::Workspace::Result.new(success?: true, output: "", error: "")
    end
  end
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
