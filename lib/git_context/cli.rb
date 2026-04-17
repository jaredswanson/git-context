# frozen_string_literal: true

require "optparse"

module GitContext
  # Parses argv into a resolved (preset, sections, repo_path) triple and runs
  # a Report. All user-facing errors go to stderr and exit nonzero.
  class CLI
    PRESETS = {
      "commit"     => -> { GitContext::Commit::Preset.new },
      "repo-audit" => -> { GitContext::RepoAudit::Preset.new }
    }.freeze

    def initialize(argv:, stdout: $stdout, stderr: $stderr)
      @argv = argv.dup
      @stdout = stdout
      @stderr = stderr
    end

    def run
      handle_early_flags
      options = parse_options
      preset = resolve_preset(options.fetch(:preset))

      if options[:list_sections]
        preset.available_tokens.each { |t| @stdout.puts t }
        return
      end

      tokens = resolve_tokens(preset, options)
      sections = tokens.map { |t| preset.section_for(t) }

      git = Git.new(options[:repo] || Dir.pwd)
      @stdout.puts Report.new(git: git, sections: sections).to_s
    rescue ArgumentError => e
      abort_with(e.message)
    end

    private

    def handle_early_flags
      if (@argv & %w[--help -h]).any?
        @stdout.puts build_parser({}).help
        exit(0)
      end

      if @argv == ["--list-sections"] || (@argv.length == 1 && @argv.first == "--list-sections")
        PRESETS.each do |name, factory|
          preset = factory.call
          @stdout.puts "#{name}:"
          preset.available_tokens.each { |t| @stdout.puts "  #{t}" }
        end
        exit(0)
      end
    end

    def build_parser(options)
      preset_list = PRESETS.keys.join(", ")
      OptionParser.new do |o|
        o.banner = "Usage: git-context <preset> [options]\n\nPresets: #{preset_list}\n\nOptions:"
        o.on("--repo PATH", "Repo path (default: cwd)") { |v| options[:repo] = v }
        o.on("--only LIST", Array, "Run only these sections") { |v| options[:only] = v }
        o.on("--add LIST", Array, "Add sections to preset") { |v| options[:add] = v }
        o.on("--skip LIST", Array, "Remove sections from preset") { |v| options[:skip] = v }
        o.on("--list-sections", "List available sections and exit") { options[:list_sections] = true }
        o.on("-h", "--help", "Show this help") { @stdout.puts o; exit(0) }
      end
    end

    def parse_options
      options = { only: nil, add: [], skip: [] }
      parser = build_parser(options)

      preset = @argv.shift
      if preset.nil? || preset.start_with?("-")
        @stderr.puts parser.help
        exit(1)
      end
      options[:preset] = preset

      parser.parse!(@argv)
      options
    end

    def resolve_preset(name)
      factory = PRESETS[name]
      unless factory
        raise ArgumentError, "unknown preset '#{name}'. Available: #{PRESETS.keys.join(', ')}"
      end
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
          "unknown section '#{unknown.first}' for preset '#{preset.name}'. Available: #{preset.available_tokens.join(', ')}"
      end
      tokens
    end

    def abort_with(message)
      @stderr.puts message
      exit(1)
    end
  end
end
