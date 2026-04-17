# frozen_string_literal: true

require "open3"

module GitContext
  # Thin wrapper around shelling out to `git`. This is the single seam where
  # we talk to the outside world — other objects should depend on this, not
  # on Open3 directly, so they can be unit-tested with a fake.
  class Git
    class Error < StandardError; end

    attr_reader :repo_path

    def initialize(repo_path)
      @repo_path = repo_path
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

    def ls_files
      run("ls-files").split("\n").reject(&:empty?)
    end

    def ignored?(path)
      # git check-ignore returns 0 when the path is ignored, 1 when not.
      _out, _err, status = Open3.capture3("git", "-C", @repo_path, "check-ignore", "-q", "--", path)
      status.exitstatus == 0
    end

    # Returns an Array<String> of repo-relative paths. Directories get a
    # trailing "/". The ".git" directory is pruned. Order is not guaranteed.
    def walk_working_tree
      paths = []
      walk_dir(@repo_path, "", paths)
      paths
    end

    # Returns Dir.children(File.join(@repo_path, subpath)). No filtering, no
    # sorting. Raises if the resolved path escapes the repo.
    def entries(subpath = ".")
      resolved = File.expand_path(File.join(@repo_path, subpath))
      raise ArgumentError, "subpath escapes repo root" unless resolved == @repo_path || resolved.start_with?("#{@repo_path}/")

      Dir.children(resolved)
    end

    def read_file(path)
      full = File.join(@repo_path, path)
      return "(directory)\n" if File.directory?(full)

      File.read(full)
    end

    private

    def walk_dir(abs_dir, prefix, paths)
      Dir.children(abs_dir).each do |child|
        next if child == ".git"

        abs_child = File.join(abs_dir, child)
        rel = "#{prefix}#{child}"

        if File.directory?(abs_child)
          paths << "#{rel}/"
          walk_dir(abs_child, "#{rel}/", paths)
        else
          paths << rel
        end
      end
    end

    def parse_name_status(output)
      output.split("\n").reject(&:empty?)
    end

    def run(*args)
      out, err, status = Open3.capture3("git", "-C", @repo_path, *args)
      raise Error, "git #{args.join(' ')} failed: #{err}" unless status.success?

      out
    end
  end
end
