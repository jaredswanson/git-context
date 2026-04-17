# frozen_string_literal: true

require "open3"

module CommitContext
  # Thin wrapper around shelling out to `git`. This is the single seam where
  # we talk to the outside world — other objects should depend on this, not
  # on Open3 directly, so they can be unit-tested with a fake.
  class Git
    class Error < StandardError; end

    def initialize(repo_path)
      @repo = repo_path
    end

    def status
      run("status", "--short")
    end

    def diff(staged:)
      args = ["diff"]
      args << "--staged" if staged
      run(*args)
    end

    def recent_log(limit:)
      run("log", "-n", limit.to_s, "--oneline")
    rescue Error
      ""
    end

    def file_log(path, limit:)
      run("log", "-n", limit.to_s, "--oneline", "--", path)
    rescue Error
      ""
    end

    def modified_files
      parse_name_status(run("diff", "--name-only", "HEAD"))
    rescue Error
      []
    end

    def untracked_files
      run("ls-files", "--others", "--exclude-standard").split("\n").reject(&:empty?)
    end

    def read_file(path)
      full = File.join(@repo, path)
      return "(directory)\n" if File.directory?(full)

      File.read(full)
    end

    private

    def parse_name_status(output)
      output.split("\n").reject(&:empty?)
    end

    def run(*args)
      out, err, status = Open3.capture3("git", "-C", @repo, *args)
      raise Error, "git #{args.join(' ')} failed: #{err}" unless status.success?

      out
    end
  end
end
