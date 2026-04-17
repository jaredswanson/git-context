# frozen_string_literal: true

require "optparse"
require "git_context/repo_init/licenses/mit"

module GitContext
  module RepoInit
    # Orchestrates the repo-init action: pre-flight audit, auto-applied
    # bootstrap (init, gitignore, initial commit, license), and remote
    # proposals. Collaborates with Git (read+write), Workspace (filesystem
    # writes + gh/tea), and JsonReport (structured output).
    class Command
      VERSION_TAG = "0.4.0"

      def initialize(git:, workspace:, argv: [], stdout: $stdout, stderr: $stderr)
        @git = git
        @workspace = workspace
        @argv = argv.dup
        @stdout = stdout
        @stderr = stderr
        @report = JsonReport.new(command: "repo-init")
        @options = default_options
      end

      def run
        parse_options
        return if @options[:help_shown]

        record_audit_findings
        stacks = detect_stacks
        defaults = heuristic_defaults
        bootstrap(stacks)
        maybe_license(defaults)
        remote_step(defaults)

        emit
      end

      private

      def default_options
        {
          host: nil,
          visibility: nil,
          yes: false,
          json: false,
          dry_run: false,
          help_shown: false
        }
      end

      def parse_options
        parser = OptionParser.new do |o|
          o.banner = "Usage: git-context repo-init [options]"
          o.on("--host HOST", %w[github forgejo]) { |v| @options[:host] = v }
          o.on("--visibility VIS", %w[public private]) { |v| @options[:visibility] = v }
          o.on("--yes") { @options[:yes] = true }
          o.on("--json") { @options[:json] = true }
          o.on("--dry-run") { @options[:dry_run] = true }
          o.on("--repo PATH") { |_v| } # consumed by CLI; present for help
          o.on("-h", "--help") do
            @stdout.puts o
            @options[:help_shown] = true
          end
        end
        parser.parse!(@argv)
        exit(0) if @options[:help_shown]
      end

      def record_audit_findings
        findings = {}
        preset = GitContext::RepoAudit::Preset.new
        preset.default_tokens.each do |token|
          section = preset.section_for(token)
          findings[token] = section.render(@git)
        end
        @report.merge_context("audit_findings" => findings)
      rescue StandardError => e
        @report.merge_context("audit_findings" => {})
        @report.add_warning(kind: "audit_failed", description: e.message)
      end

      def detect_stacks
        detector = StackDetector.new(git: @git)
        stacks = detector.stacks
        @report.merge_context(
          "stack" => stacks.first.to_s,
          "detected_stacks" => stacks.map(&:to_s)
        )
        stacks
      end

      def heuristic_defaults
        detector = StackDetector.new(git: @git)
        open_source = detector.likely_open_source?
        if open_source.value
          host = @options[:host] || "github"
          visibility = @options[:visibility] || "public"
        else
          host = @options[:host] || "forgejo"
          visibility = @options[:visibility] || "private"
        end
        {
          host: host,
          visibility: visibility,
          open_source: open_source.value,
          explicit_visibility: !@options[:visibility].nil?
        }
      end

      def bootstrap(stacks)
        ensure_git_init
        ensure_gitignore(stacks)
        ensure_initial_commit
      end

      def ensure_git_init
        return if @workspace.file_exists?(".git")

        if @options[:dry_run]
          @report.add_proposal(
            kind: "git_init",
            description: "Initialize git repository on branch main",
            details: { "branch" => "main" }
          )
          return
        end

        @git.init_repo(branch: "main")
        @report.add_action(
          kind: "git_init",
          description: "Initialized git repository on branch main",
          details: { "branch" => "main" }
        )
      end

      def ensure_gitignore(stacks)
        existing_lines = @workspace.read_lines(".gitignore").map { |l| l.chomp }
        existing = existing_lines.reject { |l| l.strip.empty? || l.start_with?("#") }
        all_patterns = GitignorePatterns.merged(stacks)
        missing = all_patterns - existing
        skipped = all_patterns - missing
        return if missing.empty?

        if @options[:dry_run]
          @report.add_proposal(
            kind: "gitignore_append",
            description: "Append #{missing.length} gitignore patterns",
            details: { "patterns_added" => missing, "patterns_skipped" => skipped }
          )
          return
        end

        header = "# Added by git-context v#{VERSION_TAG} (stack: #{stacks.join(', ')})\n"
        body = missing.map { |p| "#{p}\n" }.join
        prefix = existing_lines.empty? ? "" : "\n"
        @workspace.append_file(".gitignore", "#{prefix}#{header}#{body}")
        @report.add_action(
          kind: "gitignore_append",
          description: "Appended #{missing.length} patterns to .gitignore",
          details: { "patterns_added" => missing, "patterns_skipped" => skipped }
        )
      end

      def ensure_initial_commit
        return if @git.has_commits?

        if @options[:dry_run]
          @report.add_proposal(
            kind: "initial_commit",
            description: "Create initial commit including .gitignore",
            details: { "files" => [".gitignore"] }
          )
          @initial_commit_emitted = false
          return
        end

        @git.add(".gitignore")
        sha = @git.commit("Initial commit")
        @report.add_action(
          kind: "initial_commit",
          description: "Created initial commit",
          details: { "sha" => sha, "files" => [".gitignore"] }
        )
        @initial_commit_emitted = true
      end

      def maybe_license(defaults)
        return if @workspace.file_exists?("LICENSE") && propose_replace_license
        return unless should_create_license?(defaults)

        if @options[:dry_run]
          @report.add_proposal(
            kind: "license_created",
            description: "Create MIT LICENSE",
            details: { "license" => "MIT" }
          )
          return
        end

        write_license
      end

      def propose_replace_license
        @report.add_proposal(
          kind: "replace_license",
          description: "LICENSE already exists; replace only if intentional",
          details: { "path" => "LICENSE" },
          suggested_command: "rm LICENSE && git-context repo-init --yes"
        )
        true
      end

      def should_create_license?(defaults)
        return false if @workspace.file_exists?("LICENSE")
        return false unless defaults[:open_source]
        return false if @options[:visibility] == "private"

        true
      end

      def write_license
        holder = @git.config_get("user.name") || ENV["GIT_AUTHOR_NAME"] || "Copyright Holder"
        body = format(GitContext::RepoInit::Licenses::MIT, year: 2026, holder: holder)
        @workspace.write_file("LICENSE", body)
        @git.add("LICENSE")
        @git.commit("Add MIT LICENSE") if @git.has_commits?
        @report.add_action(
          kind: "license_created",
          description: "Created MIT LICENSE",
          details: { "holder" => holder, "year" => 2026 }
        )
      end

      def remote_step(defaults)
        return if @git.has_remote?("origin")

        name = File.basename(@workspace.repo_path)
        host = defaults[:host]
        visibility = defaults[:visibility]
        suggested = suggested_remote_command(host, visibility, name)
        details = { "host" => host, "visibility" => visibility, "name" => name }

        if @options[:yes] && !@options[:dry_run]
          execute_remote(host, visibility, name, details, suggested)
        else
          @report.add_proposal(
            kind: "create_remote",
            description: "Create #{visibility} #{host} repository and push",
            details: details,
            suggested_command: suggested
          )
        end
      end

      def suggested_remote_command(host, visibility, name)
        if host == "github"
          "gh repo create #{name} --#{visibility} --source=. --remote=origin --push"
        else
          "tea repos create --name #{name} && git remote add origin <url> && git push -u origin main"
        end
      end

      def execute_remote(host, visibility, name, details, suggested)
        result =
          if host == "github"
            @workspace.run_gh("repo", "create", name, "--#{visibility}",
                              "--source=.", "--remote=origin", "--push")
          else
            @workspace.run_tea("repos", "create", "--name", name)
          end

        if result.success?
          @report.add_action(
            kind: "remote_created",
            description: "Created #{host} remote 'origin'",
            details: details
          )
        else
          @report.add_proposal(
            kind: "create_remote",
            description: "Create #{visibility} #{host} repository and push",
            details: details,
            suggested_command: suggested
          )
          @report.add_warning(kind: "remote_create_failed", description: result.error.to_s)
        end
      end

      def emit
        if @options[:json]
          @stdout.puts @report.to_json(pretty: true)
        else
          emit_human
        end
      end

      def emit_human
        h = @report.to_h
        @stdout.puts "Actions taken:"
        h["actions_taken"].each { |a| @stdout.puts "  - #{a['kind']}: #{a['description']}" }
        @stdout.puts "  (none)" if h["actions_taken"].empty?
        @stdout.puts
        @stdout.puts "Proposals:"
        h["proposals"].each do |p|
          @stdout.puts "  - #{p['kind']}: #{p['description']}"
          @stdout.puts "      $ #{p['suggested_command']}" if p["suggested_command"]
        end
        @stdout.puts "  (none)" if h["proposals"].empty?
        return if h["warnings"].empty?

        @stdout.puts
        @stdout.puts "Warnings:"
        h["warnings"].each { |w| @stdout.puts "  - #{w['kind']}: #{w['description']}" }
      end
    end
  end
end
