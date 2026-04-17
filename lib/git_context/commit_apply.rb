# frozen_string_literal: true

require "optparse"
require "json"

module GitContext
  # Commits staged changes using a caller-supplied message. This is an action
  # command — it mutates the repo. It never stages files itself and never uses
  # `git commit -a`. The caller must supply exactly one message source:
  # --message, --message-file, or --message-stdin.
  #
  # Collaborators: a Git instance (injected), JsonReport for structured output.
  class CommitApply
    def initialize(git:, argv: [], stdin: $stdin, stdout: $stdout, stderr: $stderr)
      @git    = git
      @argv   = argv.dup
      @stdin  = stdin
      @stdout = stdout
      @stderr = stderr
    end

    def run
      options = parse_options
      message = resolve_message(options)
      validate_message!(message)

      report    = JsonReport.new(command: "commit-apply")
      had_staged = check_staged!(report, options)
      sha        = @git.commit(message)

      report.add_action(
        kind:        "commit",
        description: "Created commit #{sha}",
        details:     { "sha" => sha, "message_first_line" => message.lines.first.strip }
      )

      had_unstaged = check_unstaged!(report)
      report.merge_context("had_staged_changes" => had_staged, "had_unstaged_changes" => had_unstaged)
      emit(report, options[:json])
    end

    private

    def parse_options
      options = {}
      parser = OptionParser.new do |o|
        o.on("--message TEXT")        { |v| options[:message]        = v }
        o.on("--message-file PATH")   { |v| options[:message_file]   = v }
        o.on("--message-stdin")       { options[:message_stdin]      = true }
        o.on("--json")                { options[:json]               = true }
        o.on("--allow-empty")         { options[:allow_empty]        = true }
        o.on("--repo PATH")           { |v| options[:repo]           = v }
      end
      parser.parse!(@argv)
      options
    end

    def resolve_message(options)
      source_flags = [options[:message], options[:message_file], options[:message_stdin]].compact
      if source_flags.size > 1
        @stderr.puts "Provide exactly one of --message, --message-file, or --message-stdin."
        exit(2)
      end

      sources = [
        options[:message],
        options[:message_file] ? (
          # --message-file reads an arbitrary caller-supplied path, not a repo-root path — Workspace not used
          File.read(options[:message_file])
        ) : nil,
        options[:message_stdin] ? @stdin.read : nil
      ].compact

      if sources.empty?
        @stderr.puts "One of --message, --message-file, or --message-stdin is required."
        exit(2)
      end

      sources.first.gsub(/[\s]+\z/, "")
    end

    def validate_message!(message)
      return unless message.strip.empty?

      @stderr.puts "Commit message cannot be blank."
      exit(2)
    end

    # Returns true if staged changes exist. Exits 1 when none and --allow-empty
    # was not passed.
    def check_staged!(report, options)
      had_staged = !@git.diff(staged: true).empty?
      return had_staged if had_staged || options[:allow_empty]

      report.fail!(1)
      report.add_warning(kind: "no_staged_changes", description: "No staged changes; nothing to commit.")
      if options[:json]
        @stdout.puts report.to_json(pretty: true)
      else
        @stderr.puts "No staged changes; nothing to commit."
      end
      exit(1)
    end

    # Returns true if any modified or untracked files remain after the commit.
    def check_unstaged!(report)
      unstaged = @git.modified_files + @git.untracked_files
      return false if unstaged.empty?

      report.add_warning(
        kind:        "unstaged_changes_left",
        description: "#{unstaged.size} files have unstaged or untracked changes."
      )
      true
    end

    def emit(report, json_mode)
      if json_mode
        @stdout.puts report.to_json(pretty: true)
      else
        emit_human(report)
      end
    end

    def emit_human(report)
      h = report.to_h
      h["actions_taken"].each do |action|
        @stdout.puts "✓ #{action['description']}"
      end
      h["warnings"].each do |warning|
        @stdout.puts "! #{warning['description']}"
      end
    end
  end
end
