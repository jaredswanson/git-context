# frozen_string_literal: true

require "optparse"
require_relative "cli/preset_command"

module GitContext
  # Parses argv into a resolved command and runs it. Preset commands (commit,
  # repo-audit) emit context reports. Action commands (repo-init, commit-apply)
  # perform mutations. All user-facing errors go to stderr and exit nonzero.
  class CLI
    PRESETS = {
      "commit"     => -> { GitContext::Commit::Preset.new },
      "repo-audit" => -> { GitContext::RepoAudit::Preset.new }
    }.freeze

    ACTION_COMMANDS = {
      "repo-init"    => "Initialize a repo with curated defaults",
      "commit-apply" => "Commit staged changes with a given message"
    }.freeze

    PRESET_HANDLERS = PRESETS.keys.each_with_object({}) do |name, h|
      h[name] = ->(argv, stdout, stderr) { PresetCommand.new(name, argv, stdout, stderr).run }
    end.freeze

    ACTION_HANDLERS = {
      "repo-init" => lambda { |argv, stdout, stderr|
        argv = argv.dup
        repo = CLI.extract_repo_flag(argv) || Dir.pwd
        git = Git.new(repo)
        workspace = Workspace.new(repo)
        RepoInit::Command.new(
          git: git, workspace: workspace, argv: argv, stdout: stdout, stderr: stderr
        ).run
      },
      "commit-apply" => lambda { |argv, stdout, stderr|
        repo   = argv.include?("--repo") ? argv[argv.index("--repo") + 1] : Dir.pwd
        git    = Git.new(repo)
        CommitApply.new(git: git, argv: argv, stdout: stdout, stderr: stderr).run
      }
    }.freeze

    def self.extract_repo_flag(argv)
      idx = argv.index("--repo")
      return nil unless idx && argv[idx + 1]

      value = argv[idx + 1]
      argv.slice!(idx, 2)
      value
    end

    COMMANDS = PRESET_HANDLERS.merge(ACTION_HANDLERS).freeze

    def initialize(argv:, stdout: $stdout, stderr: $stderr)
      @argv = argv.dup
      @stdout = stdout
      @stderr = stderr
    end

    def run
      handle_early_flags
      command_name = @argv.shift

      if command_name.nil? || command_name.start_with?("-")
        @stderr.puts help_banner
        exit(1)
      end

      handler = COMMANDS[command_name]
      unless handler
        all_commands = (PRESETS.keys + ACTION_COMMANDS.keys).join(", ")
        @stderr.puts "unknown command '#{command_name}'. Available: #{all_commands}"
        exit(1)
      end

      handler.call(@argv, @stdout, @stderr)
    rescue NotImplementedError => e
      @stderr.puts e.message
      exit(2)
    rescue ArgumentError => e
      @stderr.puts e.message
      exit(1)
    end

    private

    def handle_early_flags
      if (@argv & %w[--help -h]).any?
        @stdout.puts help_banner
        exit(0)
      end

      if @argv == ["--list-sections"]
        render_list_sections_all
        exit(0)
      end
    end

    def help_banner
      preset_list = PRESETS.keys.map { |n| "  #{n}" }.join("\n")
      action_list = ACTION_COMMANDS.map { |n, desc| "  #{n.ljust(14)}#{desc}" }.join("\n")
      <<~BANNER.chomp
        Usage: git-context <command> [options]

        Preset commands (read-only, emit context):
        #{preset_list}

        Action commands:
        #{action_list}

        Options:
            --repo PATH              Repo path (default: cwd)
            --only LIST              Run only these sections
            --add LIST               Add sections to preset
            --skip LIST              Remove sections from preset
            --list-sections          List available sections and exit
        -h, --help                   Show this help
      BANNER
    end

    def render_list_sections_all
      PRESETS.each do |name, factory|
        preset = factory.call
        @stdout.puts "#{name}:"
        preset.available_tokens.each { |t| @stdout.puts "  #{t}" }
      end
    end
  end
end
