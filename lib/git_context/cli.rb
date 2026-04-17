# frozen_string_literal: true

require "optparse"

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

    COMMANDS = PRESETS.keys.each_with_object({}) do |name, h|
      h[name] = ->(argv, stdout, stderr) { PresetCommand.new(name, argv, stdout, stderr).run }
    end.merge(
      ACTION_COMMANDS.keys.each_with_object({}) do |name, h|
        h[name] = ->(_argv, _stdout, stderr) { raise NotImplementedError, "'#{name}' is not yet implemented" }
      end
    ).freeze

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
      @stderr.puts "#{e.message}"
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
        p = factory.call
        @stdout.puts "#{name}:"
        p.available_tokens.each { |t| @stdout.puts "  #{t}" }
      end
    end

    # Handles dispatch for preset-style commands (commit, repo-audit).
    # Preserves the --only/--add/--skip/--list-sections/--repo behaviour.
    class PresetCommand
      def initialize(preset_name, argv, stdout, stderr)
        @preset_name = preset_name
        @argv = argv.dup
        @stdout = stdout
        @stderr = stderr
      end

      def run
        options = parse_options
        preset = resolve_preset

        if options[:list_sections]
          preset.available_tokens.each { |t| @stdout.puts t }
          return
        end

        tokens = resolve_tokens(preset, options)
        sections = tokens.map { |t| preset.section_for(t) }

        git = Git.new(options[:repo] || Dir.pwd)
        @stdout.puts Report.new(git: git, sections: sections).to_s
      end

      private

      def parse_options
        options = { only: nil, add: [], skip: [] }
        build_parser(options).parse!(@argv)
        options
      end

      def build_parser(options)
        OptionParser.new do |o|
          o.on("--repo PATH", "Repo path (default: cwd)") { |v| options[:repo] = v }
          o.on("--only LIST", Array, "Run only these sections") { |v| options[:only] = v }
          o.on("--add LIST", Array, "Add sections to preset") { |v| options[:add] = v }
          o.on("--skip LIST", Array, "Remove sections from preset") { |v| options[:skip] = v }
          o.on("--list-sections", "List available sections and exit") { options[:list_sections] = true }
        end
      end

      def resolve_preset
        factory = CLI::PRESETS[@preset_name]
        factory.call
      end

      def resolve_tokens(preset, options)
        tokens =
          if options[:only]
            options[:only]
          else
            base = preset.default_tokens.dup
            base -= options[:skip]
            (base + options[:add]).uniq
          end

        unknown = tokens - preset.available_tokens
        unless unknown.empty?
          raise ArgumentError,
            "unknown section '#{unknown.first}' for preset '#{preset.name}'. " \
            "Available: #{preset.available_tokens.join(', ')}"
        end
        tokens
      end
    end
  end
end
