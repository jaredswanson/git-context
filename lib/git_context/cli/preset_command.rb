# frozen_string_literal: true

module GitContext
  class CLI
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
