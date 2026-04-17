# frozen_string_literal: true

require "open3"

module GitContext
  # Write-side filesystem operations and external CLI invocations (gh, tea).
  #
  # Rationale for a separate seam from Git: `Git` owns `git` CLI invocations
  # and read-side filesystem inspection (ls-files, log, diff, etc.). Write-side
  # filesystem work and *other* external CLIs (gh, tea) are a distinct concern
  # — mixing them into `Git` would give it two reasons to change. `Workspace`
  # is the second seam to the outside world so all other objects can remain
  # independently testable via `FakeWorkspace`.
  class Workspace
    Result = Struct.new(:success?, :output, :error, keyword_init: true)

    attr_reader :repo_path

    def initialize(repo_path)
      @repo_path = repo_path
    end

    # Writes +contents+ to +relative_path+ under the repo root.
    # Raises ArgumentError if +relative_path+ escapes the root.
    def write_file(relative_path, contents, mode: "w")
      full = safe_path!(relative_path)
      FileUtils.mkdir_p(File.dirname(full))
      File.open(full, mode) { |f| f.write(contents) }
    end

    # Appends +contents+ to +relative_path+.
    def append_file(relative_path, contents)
      write_file(relative_path, contents, mode: "a")
    end

    def file_exists?(relative_path)
      File.exist?(File.join(@repo_path, relative_path))
    end

    def read_lines(relative_path)
      full = File.join(@repo_path, relative_path)
      return [] unless File.exist?(full)

      File.readlines(full)
    end

    # Shells out to `gh` with the repo as the working directory.
    # Returns a Result. Never raises for expected failures.
    def run_gh(*args)
      return missing_binary_result("gh") unless which("gh")

      run_external("gh", *args)
    end

    # Shells out to `tea` with the repo as the working directory.
    # Returns a Result. Never raises for expected failures.
    def run_tea(*args)
      return missing_binary_result("tea") unless which("tea")

      run_external("tea", *args)
    end

    # Returns true if +binary+ is available on PATH.
    def which(binary)
      !`which #{Shellwords.shellescape(binary)} 2>/dev/null`.strip.empty?
    end

    private

    def safe_path!(relative_path)
      resolved = File.expand_path(File.join(@repo_path, relative_path))
      unless resolved == @repo_path || resolved.start_with?("#{@repo_path}/")
        raise ArgumentError, "relative_path escapes repo root: #{relative_path.inspect}"
      end

      resolved
    end

    def run_external(binary, *args)
      out, err, status = Dir.chdir(@repo_path) { Open3.capture3(binary, *args) }
      Result.new(success?: status.success?, output: out, error: err)
    rescue => e
      Result.new(success?: false, output: "", error: e.message)
    end

    def missing_binary_result(binary)
      Result.new(success?: false, output: "", error: "#{binary} not found on PATH")
    end
  end
end
