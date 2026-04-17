# git-context Pivot Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rename `commit-context` to `git-context`, restructure into a composable preset+sections architecture, add a `repo-audit` preset, and set project standards.

**Architecture:** Top-level `GitContext` module. Each context type (`Commit`, `RepoAudit`) is a submodule owning its own preset + sections. `Report` composes sections via duck-typed protocol. `Git` is shared. CLI takes a preset name plus `--only/--add/--skip` flags.

**Tech Stack:** Ruby 3.2+, Minitest, standard library only (`Open3`, `Dir`, `File`, `Find`). No new runtime dependencies.

**Spec:** `docs/superpowers/specs/2026-04-17-git-context-pivot-design.md`

---

## File structure (final state)

```
git-context/
├── CLAUDE.md                                        [NEW]
├── README.md                                        [REWRITE]
├── git-context.gemspec                              [RENAMED from commit-context.gemspec]
├── Gemfile
├── Rakefile
├── exe/git-context                                  [RENAMED from exe/commit_context]
├── lib/
│   ├── git_context.rb                               [RENAMED from lib/commit_context.rb]
│   └── git_context/
│       ├── version.rb                               [0.2.0]
│       ├── git.rb                                   [+ ls_files, ignored?]
│       ├── truncated_diff.rb                        [unchanged logic]
│       ├── report.rb                                [sections: now required]
│       ├── cli.rb                                   [REWRITE: presets + flags]
│       ├── commit.rb                                [NEW: requires preset + sections]
│       ├── commit/
│       │   ├── preset.rb                            [NEW]
│       │   ├── sections.rb                          [requires all]
│       │   └── sections/
│       │       ├── status.rb                        [namespace only]
│       │       ├── staged_diff.rb                   [namespace only]
│       │       ├── unstaged_diff.rb                 [namespace only]
│       │       ├── recent_log.rb                    [namespace only]
│       │       ├── file_history.rb                  [namespace only]
│       │       └── untracked_files.rb               [namespace only]
│       ├── repo_audit.rb                            [NEW]
│       └── repo_audit/
│           ├── preset.rb                            [NEW]
│           ├── offenders.rb                         [NEW]
│           ├── sections.rb                          [NEW]
│           └── sections/
│               ├── gitignore_gaps.rb                [NEW]
│               ├── tracked_secrets.rb               [NEW]
│               └── missing_standard_files.rb       [NEW]
├── test/
│   ├── test_helper.rb
│   ├── git_test.rb                                  [+ ls_files, ignored?]
│   ├── truncated_diff_test.rb
│   ├── report_test.rb
│   ├── cli_test.rb                                  [REWRITE]
│   ├── sections_test.rb                             [namespace updates]
│   └── repo_audit/
│       ├── offenders_test.rb                        [NEW]
│       ├── preset_test.rb                           [NEW]
│       └── sections/
│           ├── gitignore_gaps_test.rb               [NEW]
│           ├── tracked_secrets_test.rb              [NEW]
│           └── missing_standard_files_test.rb      [NEW]
└── docs/
    ├── standards/
    │   ├── oop-principles.md                        [NEW]
    │   ├── tdd-workflow.md                          [NEW]
    │   └── ruby-style.md                            [NEW]
    └── superpowers/
        ├── specs/2026-04-17-git-context-pivot-design.md
        └── plans/2026-04-17-git-context-pivot.md   [this file]
```

---

## Task 1: Write project standards docs + CLAUDE.md

**Files:**
- Create: `docs/standards/oop-principles.md`
- Create: `docs/standards/tdd-workflow.md`
- Create: `docs/standards/ruby-style.md`
- Create: `CLAUDE.md`

No code changes; establishes the conventions everything else follows.

- [ ] **Step 1: Write `docs/standards/oop-principles.md`**

```markdown
# OOP Principles

Follows Sandi Metz (POODR, 99 Bottles of OOP). Read those for depth; this file
is the one-page rulebook for this project.

## Rules

- **Small objects, one responsibility.** If you can't name what a class does in
  one sentence without "and", split it.
- **Inject dependencies.** Classes take collaborators in `initialize`. No global
  lookups, no hardcoded shell/filesystem calls inside domain objects.
- **Duck typing.** Depend on what an object *does*, not what it *is*. The
  section protocol (`#title`, `#render(git)`) is the canonical example —
  anything implementing it is a section.
- **Ask for what you need.** Constructor parameters spell out what the object
  depends on. No hidden reads of `ENV`, `Dir.pwd`, etc.
- **One seam to the outside.** `GitContext::Git` is the only object that shells
  out. Everything else talks to a `Git` instance (real or fake).
- **Tell, don't ask.** Sections render themselves; they aren't inspected for
  state by `Report`.

## When something grows

- A method over ~10 lines → consider extracting.
- A class over ~100 lines → consider splitting.
- Conditional dispatch on type → consider polymorphism (more sections, fewer
  ifs).
- A test that has to set up lots of state → the object under test depends on
  too much.
```

- [ ] **Step 2: Write `docs/standards/tdd-workflow.md`**

```markdown
# TDD Workflow

Red, green, refactor. Every feature starts with a failing test.

## Loop

1. Write one failing test describing the next behavior.
2. Run it. See it fail for the expected reason (not a typo).
3. Write the minimum code to make it pass.
4. Run it. See it pass.
5. Refactor (tests stay green).
6. Commit.

## What to test

- Public behavior of your class, from the outside. Inputs → outputs.
- Edge cases: empty input, missing file, git command failing.
- Do not test private methods directly — test the public interface that uses
  them.

## What to mock

- **Don't mock what you don't own.** Don't stub `Open3`, `File`, or `Dir`
  directly.
- For sections: use `FakeGit` (in `test/test_helper.rb`) — it implements the
  duck-typed Git protocol with canned data.
- For `Git` itself: use real `git` against a temp repo (`TempRepo` module in
  `test_helper.rb`). The one seam that owns shell calls is tested with real
  shell calls.
- For the CLI: pass `stdout:` and `argv:` explicitly. Assert on captured output
  and the resolved sections array, not on internal flow.

## Structure

- One test file per class. Path mirrors `lib/`.
- Test class name: `<ClassName>Test < Minitest::Test`.
- Test method name: `test_<what_it_does_in_snake_case>`.
- Arrange/act/assert — leave a blank line between phases.
```

- [ ] **Step 3: Write `docs/standards/ruby-style.md`**

```markdown
# Ruby Style

## Naming

- Classes: `CamelCase`. Modules: `CamelCase`.
- Methods, variables: `snake_case`.
- Predicates end with `?` (`#ignored?`, not `#is_ignored`).
- Mutating methods end with `!` only when a non-mutating counterpart exists.

## Files

- One class/module per file.
- File path = namespace path. `GitContext::Commit::Sections::Status` lives at
  `lib/git_context/commit/sections/status.rb`.
- Top-level require file (`lib/git_context.rb`) wires everything up.

## Methods

- Keep methods short (Sandi's "5-line rule" is aspirational, not a law).
- Guard clauses over nested conditionals.
- Use keyword args when a method takes more than one argument or the arg type
  is not obvious from the name.
- `frozen_string_literal: true` at the top of every `.rb` file.

## Comments

- Comments explain *why*, not *what*. The code says what.
- Class-level comment: one paragraph on what the class exists for and who
  collaborates with it. Skip if obvious.
- No commented-out code. Delete it; git remembers.
```

- [ ] **Step 4: Write `CLAUDE.md`**

```markdown
# git-context

Composable gem that gathers structured git state and emits it as context for
Claude Code plugins and humans. Each "context type" is a submodule under
`GitContext` with its own preset (default sections) and sections.

## Before writing code, read

- `docs/standards/oop-principles.md`
- `docs/standards/tdd-workflow.md`
- `docs/standards/ruby-style.md`

## Architecture quick reference

- `GitContext::Report` composes sections via duck typing (`#title`,
  `#render(git)`).
- `GitContext::Git` is the only object that shells out. All other objects
  depend on a `Git` instance.
- Each new section: its own file, its own test, placed under a context-type
  submodule (e.g., `GitContext::RepoAudit::Sections::MyCheck`).
- Presets are plain objects returning an instantiated `sections` array.

## Commands

- Test: `bundle exec rake test`
- All tests must pass before committing.
```

- [ ] **Step 5: Commit**

```bash
git add docs/standards CLAUDE.md
git commit -m "Add project standards docs and CLAUDE.md"
```

---

## Task 2: Rename gem and top-level module (mechanical)

**Files (renames/edits):**
- Rename: `commit-context.gemspec` → `git-context.gemspec`
- Rename: `lib/commit_context.rb` → `lib/git_context.rb`
- Rename: `lib/commit_context/` → `lib/git_context/`
- Rename: `exe/commit_context` → `exe/git-context`
- Modify: every file under `lib/` and `test/` (`CommitContext` → `GitContext`)
- Modify: `Gemfile.lock` (delete; will regenerate)
- Modify: `README.md` (see Task 10 for full rewrite — here just make references work)

No behavior change. All existing tests must pass afterward.

- [ ] **Step 1: Rename files with git mv**

```bash
git mv commit-context.gemspec git-context.gemspec
git mv lib/commit_context.rb lib/git_context.rb
git mv lib/commit_context lib/git_context
git mv exe/commit_context exe/git-context
```

- [ ] **Step 2: Replace `CommitContext` with `GitContext` across the repo**

Use grep to find all occurrences, then rewrite. Files to update (after `git mv`): `lib/git_context.rb`, everything under `lib/git_context/`, every test file, `git-context.gemspec`, `exe/git-context`.

```bash
# Find all occurrences first
grep -rn "CommitContext\|commit_context\|commit-context" lib/ test/ exe/ *.gemspec Gemfile
```

Expected: many matches. Edit each file to replace:
- Module identifier: `CommitContext` → `GitContext`
- `require "commit_context..."` → `require "git_context..."`
- `require "commit_context"` → `require "git_context"`
- In `git-context.gemspec`: `spec.name = "commit-context"` → `spec.name = "git-context"`
- In `exe/git-context`: `require "commit_context"` → `require "git_context"`; `CommitContext::CLI` → `GitContext::CLI`
- In `test/test_helper.rb`: `require "commit_context"` → `require "git_context"`; temp dir prefix `"commit_context_test"` → `"git_context_test"`

Do NOT rename test class names like `StatusSectionTest` (internal names, not public).

- [ ] **Step 3: Update `git-context.gemspec` summary/description to match new positioning**

Replace these lines in `git-context.gemspec`:

```ruby
  spec.summary = "Composable gem that gathers structured git state as context for AI tools and humans."
  spec.description = "Composes small, duck-typed 'section' objects into structured git-state reports. Ships presets for common workflows (pre-commit snapshot, repo hygiene audit) plus a CLI (`git-context <preset>`) and Ruby API for building custom compositions."
  spec.homepage = "https://github.com/jaredmswanson/git-context"
```

- [ ] **Step 4: Delete `Gemfile.lock`**

```bash
rm -f Gemfile.lock
```

It will regenerate on next `bundle install`.

- [ ] **Step 5: Bundle install + run tests**

```bash
bundle install
bundle exec rake test
```

Expected: all existing tests pass. Nothing has changed behaviorally.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "Rename commit-context to git-context"
```

---

## Task 3: Restructure commit sections under GitContext::Commit

**Files:**
- Create: `lib/git_context/commit.rb`
- Create: `lib/git_context/commit/preset.rb`
- Create: `lib/git_context/commit/sections.rb`
- Rename: `lib/git_context/sections/*.rb` → `lib/git_context/commit/sections/*.rb`
- Delete: `lib/git_context/sections.rb` (replaced by `commit/sections.rb`)
- Modify: `lib/git_context.rb` (top-level requires)
- Modify: `lib/git_context/report.rb` (remove `DEFAULT_SECTIONS`)
- Modify: `test/sections_test.rb` (namespace updates) — rename to `test/commit/sections_test.rb`
- Create: `test/commit/preset_test.rb`

Goal: existing commit sections live under `GitContext::Commit::Sections::*`. Preset is a new object. Report no longer carries a default sections list.

- [ ] **Step 1: Move section files under commit/**

```bash
mkdir -p lib/git_context/commit/sections
git mv lib/git_context/sections/status.rb lib/git_context/commit/sections/status.rb
git mv lib/git_context/sections/staged_diff.rb lib/git_context/commit/sections/staged_diff.rb
git mv lib/git_context/sections/unstaged_diff.rb lib/git_context/commit/sections/unstaged_diff.rb
git mv lib/git_context/sections/recent_log.rb lib/git_context/commit/sections/recent_log.rb
git mv lib/git_context/sections/file_history.rb lib/git_context/commit/sections/file_history.rb
git mv lib/git_context/sections/untracked_files.rb lib/git_context/commit/sections/untracked_files.rb
rmdir lib/git_context/sections
git rm lib/git_context/sections.rb
```

- [ ] **Step 2: Update namespaces in each section file**

For each of the six files under `lib/git_context/commit/sections/`, change the opening from:

```ruby
module GitContext
  module Sections
    class Status
```

to:

```ruby
module GitContext
  module Commit
    module Sections
      class Status
```

(close with three `end`s instead of two). Class body is unchanged.

- [ ] **Step 3: Create `lib/git_context/commit/sections.rb`**

```ruby
# frozen_string_literal: true

module GitContext
  module Commit
    module Sections
    end
  end
end

require "git_context/commit/sections/status"
require "git_context/commit/sections/staged_diff"
require "git_context/commit/sections/unstaged_diff"
require "git_context/commit/sections/recent_log"
require "git_context/commit/sections/file_history"
require "git_context/commit/sections/untracked_files"
```

- [ ] **Step 4: Create `lib/git_context/commit/preset.rb`**

```ruby
# frozen_string_literal: true

module GitContext
  module Commit
    # Default section composition for pre-commit context gathering.
    # Knows the token→section mapping so the CLI can resolve flag names.
    class Preset
      def name
        "commit"
      end

      def default_tokens
        %w[status staged_diff unstaged_diff recent_log file_history untracked_files]
      end

      def available_tokens
        factories.keys
      end

      def section_for(token)
        factory = factories.fetch(token) do
          raise ArgumentError, "unknown section '#{token}' for preset '#{name}'. Available: #{available_tokens.join(', ')}"
        end
        factory.call
      end

      def sections(tokens = default_tokens)
        tokens.map { |t| section_for(t) }
      end

      private

      def factories
        {
          "status"           => -> { Sections::Status.new },
          "staged_diff"      => -> { Sections::StagedDiff.new(max_lines_per_file: 200) },
          "unstaged_diff"    => -> { Sections::UnstagedDiff.new(max_lines_per_file: 200) },
          "recent_log"       => -> { Sections::RecentLog.new(limit: 5) },
          "file_history"     => -> { Sections::FileHistory.new(limit: 3) },
          "untracked_files"  => -> { Sections::UntrackedFiles.new }
        }
      end
    end
  end
end
```

- [ ] **Step 5: Create `lib/git_context/commit.rb`**

```ruby
# frozen_string_literal: true

module GitContext
  module Commit
  end
end

require "git_context/commit/sections"
require "git_context/commit/preset"
```

- [ ] **Step 6: Update `lib/git_context.rb`**

Replace entire file with:

```ruby
# frozen_string_literal: true

module GitContext
end

require "git_context/version"
require "git_context/truncated_diff"
require "git_context/git"
require "git_context/report"
require "git_context/commit"
require "git_context/cli"
```

(Note: `sections` line removed; `commit` replaces it. `repo_audit` will be added in Task 5.)

- [ ] **Step 7: Update `lib/git_context/report.rb`** — remove the default sections lambda; make `sections:` required.

Replace the file with:

```ruby
# frozen_string_literal: true

module GitContext
  # Composes sections into a single git-context string. Collaborators
  # (git + sections) are injected — Report itself has no knowledge of shell
  # or git commands and no default composition.
  class Report
    def initialize(git:, sections:)
      @git = git
      @sections = sections
    end

    def to_s
      @sections.map { |s| render_section(s) }.join("\n")
    end

    private

    def render_section(section)
      body = section.render(@git)
      body = body.end_with?("\n") ? body : "#{body}\n"
      "## #{section.title}\n#{body}"
    end
  end
end
```

- [ ] **Step 8: Move sections test under test/commit/**

```bash
mkdir -p test/commit
git mv test/sections_test.rb test/commit/sections_test.rb
```

In `test/commit/sections_test.rb`, replace every occurrence of `CommitContext::Sections::` and `GitContext::Sections::` with `GitContext::Commit::Sections::`.

- [ ] **Step 9: Write failing test for Commit::Preset**

Create `test/commit/preset_test.rb`:

```ruby
# frozen_string_literal: true

require "test_helper"

class CommitPresetTest < Minitest::Test
  def test_name_is_commit
    assert_equal "commit", GitContext::Commit::Preset.new.name
  end

  def test_sections_returns_instances_for_default_tokens
    preset = GitContext::Commit::Preset.new
    sections = preset.sections

    assert_equal preset.default_tokens.size, sections.size
    sections.each { |s| assert_respond_to s, :title }
    sections.each { |s| assert_respond_to s, :render }
  end

  def test_sections_with_explicit_tokens_returns_only_those
    preset = GitContext::Commit::Preset.new
    sections = preset.sections(%w[status recent_log])

    assert_equal 2, sections.size
    assert_instance_of GitContext::Commit::Sections::Status, sections[0]
    assert_instance_of GitContext::Commit::Sections::RecentLog, sections[1]
  end

  def test_section_for_unknown_token_raises_with_suggestion
    preset = GitContext::Commit::Preset.new
    err = assert_raises(ArgumentError) { preset.section_for("bogus") }
    assert_match(/unknown section 'bogus'/, err.message)
    assert_match(/Available:/, err.message)
  end

  def test_available_tokens_includes_all_defaults
    preset = GitContext::Commit::Preset.new
    assert_empty(preset.default_tokens - preset.available_tokens)
  end
end
```

- [ ] **Step 10: Update `test/report_test.rb`** — `Report` no longer has a default; every test must pass `sections:`.

Audit `test/report_test.rb`. Any test that constructs `Report.new(git: ...)` without `sections:` must be updated to pass an explicit sections array (use a simple fake or `GitContext::Commit::Preset.new.sections([...])`). This is mechanical.

- [ ] **Step 11: Update `exe/git-context` and `lib/git_context/cli.rb` to stay working until Task 4**

Before the CLI rewrite lands, make the existing CLI instantiate sections via the preset. Replace `lib/git_context/cli.rb` with a temporary minimal version that still works:

```ruby
# frozen_string_literal: true

module GitContext
  class CLI
    def initialize(argv:, stdout: $stdout)
      @argv = argv
      @stdout = stdout
    end

    def run
      repo = @argv.first || Dir.pwd
      sections = GitContext::Commit::Preset.new.sections
      @stdout.puts Report.new(git: Git.new(repo), sections: sections).to_s
    end
  end
end
```

`test/cli_test.rb` should still pass (it asserts on output, not on internal section list). If it breaks, note which assertion fails and fix before committing.

- [ ] **Step 12: Run tests**

```bash
bundle exec rake test
```

Expected: all existing tests + new preset tests pass.

- [ ] **Step 13: Commit**

```bash
git add -A
git commit -m "Restructure commit sections under GitContext::Commit with Preset"
```

---

## Task 4: Rewrite CLI with presets + flag overrides

**Files:**
- Modify: `lib/git_context/cli.rb` (full rewrite)
- Modify: `test/cli_test.rb` (full rewrite)

Goal: `git-context <preset> [--repo PATH] [--only a,b] [--add a,b] [--skip a,b] [--list-sections]`.

- [ ] **Step 1: Write failing CLI tests**

Replace `test/cli_test.rb`:

```ruby
# frozen_string_literal: true

require "test_helper"

class CLITest < Minitest::Test
  include TempRepo

  def test_runs_commit_preset_by_default_tokens_against_repo_flag
    in_temp_repo do |dir|
      write_file("a.rb", "hi")
      git("add a.rb")

      out = StringIO.new
      GitContext::CLI.new(argv: ["commit", "--repo", dir], stdout: out).run

      assert_match(/## Status/, out.string)
      assert_match(/## Staged changes/, out.string)
    end
  end

  def test_only_flag_restricts_sections
    in_temp_repo do |dir|
      out = StringIO.new
      GitContext::CLI.new(argv: ["commit", "--repo", dir, "--only", "status"], stdout: out).run

      assert_match(/## Status/, out.string)
      refute_match(/## Staged changes/, out.string)
    end
  end

  def test_skip_flag_removes_sections
    in_temp_repo do |dir|
      out = StringIO.new
      GitContext::CLI.new(
        argv: ["commit", "--repo", dir, "--skip", "staged_diff,unstaged_diff"],
        stdout: out
      ).run

      assert_match(/## Status/, out.string)
      refute_match(/## Staged changes/, out.string)
      refute_match(/## Unstaged changes/, out.string)
    end
  end

  def test_add_flag_is_additive
    # For a single-preset world this is hard to demonstrate without duplicate
    # tokens; verify add of a token already in the preset is idempotent by
    # checking the token still appears exactly once in output.
    in_temp_repo do |dir|
      out = StringIO.new
      GitContext::CLI.new(
        argv: ["commit", "--repo", dir, "--add", "status"],
        stdout: out
      ).run

      assert_equal 1, out.string.scan(/^## Status$/).size
    end
  end

  def test_list_sections_prints_tokens_and_exits
    out = StringIO.new
    GitContext::CLI.new(argv: ["commit", "--list-sections"], stdout: out).run

    GitContext::Commit::Preset.new.available_tokens.each do |token|
      assert_match(/^#{Regexp.escape(token)}$/, out.string)
    end
  end

  def test_unknown_preset_errors_with_suggestion
    err = StringIO.new
    assert_raises(SystemExit) do
      GitContext::CLI.new(argv: ["bogus"], stdout: StringIO.new, stderr: err).run
    end
    assert_match(/unknown preset 'bogus'/, err.string)
    assert_match(/Available: commit/, err.string)
  end

  def test_unknown_section_errors_with_suggestion
    err = StringIO.new
    assert_raises(SystemExit) do
      GitContext::CLI.new(
        argv: ["commit", "--only", "bogus"], stdout: StringIO.new, stderr: err
      ).run
    end
    assert_match(/unknown section 'bogus'/, err.string)
  end

  def test_missing_preset_arg_prints_help_and_exits
    err = StringIO.new
    assert_raises(SystemExit) do
      GitContext::CLI.new(argv: [], stdout: StringIO.new, stderr: err).run
    end
    assert_match(/Usage:/, err.string)
  end
end
```

Add `require "stringio"` to `test/test_helper.rb` if not present.

- [ ] **Step 2: Run tests to confirm they fail**

```bash
bundle exec rake test TEST=test/cli_test.rb
```

Expected: multiple failures (current CLI doesn't support flags).

- [ ] **Step 3: Implement new CLI**

Replace `lib/git_context/cli.rb`:

```ruby
# frozen_string_literal: true

require "optparse"

module GitContext
  # Parses argv into a resolved (preset, sections, repo_path) triple and runs
  # a Report. All user-facing errors go to stderr and exit nonzero.
  class CLI
    PRESETS = {
      "commit"     => -> { GitContext::Commit::Preset.new }
      # "repo-audit" is registered in Task 5.
    }.freeze

    def initialize(argv:, stdout: $stdout, stderr: $stderr)
      @argv = argv.dup
      @stdout = stdout
      @stderr = stderr
    end

    def run
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

    def parse_options
      options = { only: nil, add: [], skip: [] }
      parser = OptionParser.new do |o|
        o.banner = "Usage: git-context <preset> [options]"
        o.on("--repo PATH", "Repo path (default: cwd)") { |v| options[:repo] = v }
        o.on("--only LIST", Array, "Run only these sections") { |v| options[:only] = v }
        o.on("--add LIST", Array, "Add sections to preset") { |v| options[:add] = v }
        o.on("--skip LIST", Array, "Remove sections from preset") { |v| options[:skip] = v }
        o.on("--list-sections", "List available sections and exit") { options[:list_sections] = true }
        o.on("-h", "--help", "Show this help") { @stdout.puts o; exit(0) }
      end

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
```

- [ ] **Step 4: Run tests to verify pass**

```bash
bundle exec rake test TEST=test/cli_test.rb
bundle exec rake test
```

Expected: full suite passes.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "Rewrite CLI with preset + flag overrides (--only/--add/--skip/--list-sections)"
```

---

## Task 5: Add RepoAudit::Offenders

**Files:**
- Create: `lib/git_context/repo_audit.rb`
- Create: `lib/git_context/repo_audit/offenders.rb`
- Create: `test/repo_audit/offenders_test.rb`
- Modify: `lib/git_context.rb` (require `repo_audit`)

`Offenders` is a shared data module used by `GitignoreGaps` and `TrackedSecrets`.

- [ ] **Step 1: Write failing test**

Create `test/repo_audit/offenders_test.rb`:

```ruby
# frozen_string_literal: true

require "test_helper"

class OffendersTest < Minitest::Test
  def test_all_patterns_is_nonempty_and_frozen
    assert_kind_of Array, GitContext::RepoAudit::Offenders.all_patterns
    refute_empty GitContext::RepoAudit::Offenders.all_patterns
    assert GitContext::RepoAudit::Offenders.all_patterns.frozen?
  end

  def test_categories_are_grouped
    cats = GitContext::RepoAudit::Offenders::CATEGORIES
    assert cats.key?(:env_files)
    assert_includes cats[:env_files], ".env"
  end

  def test_secret_patterns_include_pem_and_rsa
    patterns = GitContext::RepoAudit::Offenders::SECRET_PATTERNS
    assert_includes patterns, "*.pem"
    assert_includes patterns, "id_rsa*"
  end

  def test_matches_handles_directory_prefix
    assert GitContext::RepoAudit::Offenders.matches?("node_modules/x/y.js", "node_modules/")
    refute GitContext::RepoAudit::Offenders.matches?("src/node_modules_like.js", "node_modules/")
  end

  def test_matches_handles_glob
    assert GitContext::RepoAudit::Offenders.matches?("errors.log", "*.log")
    assert GitContext::RepoAudit::Offenders.matches?("foo/bar/baz.log", "*.log")
    refute GitContext::RepoAudit::Offenders.matches?("foo/bar/baz.txt", "*.log")
  end

  def test_matches_handles_plain_basename
    assert GitContext::RepoAudit::Offenders.matches?(".env", ".env")
    assert GitContext::RepoAudit::Offenders.matches?("config/.env", ".env")
    refute GitContext::RepoAudit::Offenders.matches?(".envrc", ".env")
  end
end
```

- [ ] **Step 2: Confirm it fails**

```bash
bundle exec rake test TEST=test/repo_audit/offenders_test.rb
```

Expected: fails (module not defined).

- [ ] **Step 3: Implement Offenders**

Create `lib/git_context/repo_audit/offenders.rb`:

```ruby
# frozen_string_literal: true

module GitContext
  module RepoAudit
    # Shared data module: the list of filename patterns that commonly indicate
    # a repo-hygiene problem. Grouped by category so sections can report them
    # meaningfully.
    module Offenders
      CATEGORIES = {
        env_files:      %w[.env .env.*],
        dep_dirs:       %w[node_modules/ vendor/bundle/],
        os_editor:      %w[.DS_Store .idea/ .vscode/ *.swp],
        build_runtime:  %w[tmp/ log/ *.log coverage/],
        databases:      %w[*.sqlite3]
      }.freeze

      SECRET_PATTERNS = %w[*.pem *.key id_rsa* *credentials* *secret*].freeze

      ALL_PATTERNS = CATEGORIES.values.flatten.freeze

      def self.all_patterns
        ALL_PATTERNS
      end

      # Match a relative path against one offender pattern.
      # Directory patterns (ending in "/") match any path under that directory.
      # Glob patterns are matched against both the full path and the basename
      # so that "*.log" catches "errors.log" and "foo/bar/baz.log".
      # Plain names (no slash, no glob) match the basename only.
      def self.matches?(path, pattern)
        if pattern.end_with?("/")
          prefix = pattern
          path.start_with?(prefix) || path.include?("/#{prefix}")
        elsif pattern.include?("*") || pattern.include?("?")
          File.fnmatch(pattern, path, File::FNM_PATHNAME) ||
            File.fnmatch(pattern, File.basename(path))
        else
          File.basename(path) == pattern
        end
      end
    end
  end
end
```

- [ ] **Step 4: Create `lib/git_context/repo_audit.rb`**

```ruby
# frozen_string_literal: true

module GitContext
  module RepoAudit
  end
end

require "git_context/repo_audit/offenders"
# sections + preset wired in Tasks 6–9.
```

- [ ] **Step 5: Register in `lib/git_context.rb`**

Insert `require "git_context/repo_audit"` between the `commit` and `cli` lines:

```ruby
require "git_context/commit"
require "git_context/repo_audit"
require "git_context/cli"
```

- [ ] **Step 6: Run tests**

```bash
bundle exec rake test
```

Expected: all pass.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "Add RepoAudit::Offenders shared pattern data"
```

---

## Task 6: Extend Git with ls_files and ignored?

**Files:**
- Modify: `lib/git_context/git.rb`
- Modify: `test/git_test.rb`

`RepoAudit` sections need two new Git methods. Put them on `Git` so the one-seam rule holds.

- [ ] **Step 1: Write failing tests**

Append to `test/git_test.rb` (inside existing test class, or add a new one — follow the existing file's pattern):

```ruby
class GitLsFilesTest < Minitest::Test
  include TempRepo

  def test_ls_files_returns_tracked_files
    in_temp_repo do |dir|
      write_file("a.rb", "a")
      write_file("sub/b.rb", "b")
      git("add -A")
      git("commit -q -m init")

      files = GitContext::Git.new(dir).ls_files
      assert_includes files, "a.rb"
      assert_includes files, "sub/b.rb"
    end
  end

  def test_ls_files_is_empty_for_fresh_repo
    in_temp_repo do |dir|
      assert_empty GitContext::Git.new(dir).ls_files
    end
  end
end

class GitIgnoredTest < Minitest::Test
  include TempRepo

  def test_ignored_returns_true_when_path_matches_gitignore
    in_temp_repo do |dir|
      write_file(".gitignore", "*.log\n")
      assert GitContext::Git.new(dir).ignored?("errors.log")
    end
  end

  def test_ignored_returns_false_when_path_does_not_match
    in_temp_repo do |dir|
      write_file(".gitignore", "*.log\n")
      refute GitContext::Git.new(dir).ignored?("app.rb")
    end
  end

  def test_ignored_returns_false_when_no_gitignore
    in_temp_repo do |dir|
      refute GitContext::Git.new(dir).ignored?("anything.log")
    end
  end
end
```

- [ ] **Step 2: Confirm failing**

```bash
bundle exec rake test TEST=test/git_test.rb
```

Expected: 5 failures (3 new tests; NoMethodError).

- [ ] **Step 3: Implement the methods**

In `lib/git_context/git.rb`, add after `untracked_files`:

```ruby
    def ls_files
      run("ls-files").split("\n").reject(&:empty?)
    end

    def ignored?(path)
      # git check-ignore returns 0 when the path is ignored, 1 when not.
      _out, _err, status = Open3.capture3("git", "-C", @repo, "check-ignore", "-q", "--", path)
      status.exitstatus == 0
    end
```

- [ ] **Step 4: Run tests**

```bash
bundle exec rake test TEST=test/git_test.rb
bundle exec rake test
```

Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "Extend Git with ls_files and ignored? for repo-audit sections"
```

---

## Task 7: Add RepoAudit::Sections::MissingStandardFiles (simplest, first)

**Files:**
- Create: `lib/git_context/repo_audit/sections/missing_standard_files.rb`
- Create: `test/repo_audit/sections/missing_standard_files_test.rb`

- [ ] **Step 1: Write failing test**

Create `test/repo_audit/sections/missing_standard_files_test.rb`:

```ruby
# frozen_string_literal: true

require "test_helper"

class MissingStandardFilesSectionTest < Minitest::Test
  include TempRepo

  def test_title
    section = GitContext::RepoAudit::Sections::MissingStandardFiles.new
    assert_equal "Missing standard files", section.title
  end

  def test_reports_missing_files
    in_temp_repo do |dir|
      section = GitContext::RepoAudit::Sections::MissingStandardFiles.new
      out = section.render(GitContext::Git.new(dir))

      assert_includes out, "README"
      assert_includes out, "LICENSE"
      assert_includes out, ".gitignore"
    end
  end

  def test_reports_all_present_when_present
    in_temp_repo do |dir|
      write_file("README.md", "x")
      write_file("LICENSE", "x")
      write_file(".gitignore", "x")

      section = GitContext::RepoAudit::Sections::MissingStandardFiles.new
      out = section.render(GitContext::Git.new(dir))

      assert_match(/All standard files present/, out)
    end
  end

  def test_readme_match_is_case_insensitive
    in_temp_repo do |dir|
      write_file("readme.md", "x")

      section = GitContext::RepoAudit::Sections::MissingStandardFiles.new
      out = section.render(GitContext::Git.new(dir))

      refute_match(/README/, out)
    end
  end

  def test_readme_prefix_match
    in_temp_repo do |dir|
      write_file("README.rst", "x")

      section = GitContext::RepoAudit::Sections::MissingStandardFiles.new
      out = section.render(GitContext::Git.new(dir))

      refute_match(/^README/, out.strip)
    end
  end
end
```

- [ ] **Step 2: Confirm failing**

```bash
bundle exec rake test TEST=test/repo_audit/sections/missing_standard_files_test.rb
```

Expected: failure (class not defined).

- [ ] **Step 3: Add Git#repo_path accessor** — the section needs to inspect the filesystem of the repo; the existing `Git` does not expose its path. Add a reader.

In `lib/git_context/git.rb`, add after `def initialize(repo_path)` block:

```ruby
    attr_reader :repo_path
```

And rename the instance variable for clarity:

```ruby
    def initialize(repo_path)
      @repo_path = repo_path
    end
```

Then update references: `@repo` → `@repo_path` throughout the file (occurs in `read_file` and `run`).

- [ ] **Step 4: Implement the section**

Create `lib/git_context/repo_audit/sections/missing_standard_files.rb`:

```ruby
# frozen_string_literal: true

module GitContext
  module RepoAudit
    module Sections
      # Reports which conventional repo files are missing.
      # Matches README*/LICENSE* case-insensitively; .gitignore exactly.
      class MissingStandardFiles
        STANDARDS = [
          { label: "README",     prefix: "readme",   exact: false },
          { label: "LICENSE",    prefix: "license",  exact: false },
          { label: ".gitignore", prefix: ".gitignore", exact: true }
        ].freeze

        def title
          "Missing standard files"
        end

        def render(git)
          missing = STANDARDS.reject { |s| present?(git.repo_path, s) }
          return "All standard files present\n" if missing.empty?

          missing.map { |s| "- #{s[:label]}" }.join("\n") + "\n"
        end

        private

        def present?(repo_path, standard)
          entries = Dir.children(repo_path)
          if standard[:exact]
            entries.include?(standard[:prefix])
          else
            entries.any? { |e| e.downcase.start_with?(standard[:prefix]) }
          end
        end
      end
    end
  end
end
```

- [ ] **Step 5: Run tests**

```bash
bundle exec rake test TEST=test/repo_audit/sections/missing_standard_files_test.rb
bundle exec rake test
```

Expected: all pass (including previously passing tests — the `@repo` → `@repo_path` rename is internal).

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "Add RepoAudit::Sections::MissingStandardFiles + Git#repo_path"
```

---

## Task 8: Add RepoAudit::Sections::TrackedSecrets

**Files:**
- Create: `lib/git_context/repo_audit/sections/tracked_secrets.rb`
- Create: `test/repo_audit/sections/tracked_secrets_test.rb`

- [ ] **Step 1: Write failing test**

Create `test/repo_audit/sections/tracked_secrets_test.rb`:

```ruby
# frozen_string_literal: true

require "test_helper"

class TrackedSecretsSectionTest < Minitest::Test
  include TempRepo

  def test_title
    assert_equal "Tracked secrets", GitContext::RepoAudit::Sections::TrackedSecrets.new.title
  end

  def test_flags_tracked_env_file
    in_temp_repo do |dir|
      write_file(".env", "SECRET=1")
      write_file("app.rb", "x")
      git("add -A")
      git("commit -q -m init")

      out = GitContext::RepoAudit::Sections::TrackedSecrets.new.render(GitContext::Git.new(dir))
      assert_match(/\.env/, out)
      refute_match(/app\.rb/, out)
      assert_match(/git rm --cached/, out)
    end
  end

  def test_flags_tracked_pem_file
    in_temp_repo do |dir|
      write_file("cert.pem", "x")
      git("add cert.pem")
      git("commit -q -m init")

      out = GitContext::RepoAudit::Sections::TrackedSecrets.new.render(GitContext::Git.new(dir))
      assert_match(/cert\.pem/, out)
    end
  end

  def test_none_marker_when_nothing_flagged
    in_temp_repo do |dir|
      write_file("app.rb", "x")
      git("add app.rb")
      git("commit -q -m init")

      out = GitContext::RepoAudit::Sections::TrackedSecrets.new.render(GitContext::Git.new(dir))
      assert_match(/No tracked secrets/, out)
    end
  end

  def test_empty_repo_returns_none
    in_temp_repo do |dir|
      out = GitContext::RepoAudit::Sections::TrackedSecrets.new.render(GitContext::Git.new(dir))
      assert_match(/No tracked secrets/, out)
    end
  end
end
```

- [ ] **Step 2: Confirm failing**

```bash
bundle exec rake test TEST=test/repo_audit/sections/tracked_secrets_test.rb
```

Expected: failures.

- [ ] **Step 3: Implement the section**

Create `lib/git_context/repo_audit/sections/tracked_secrets.rb`:

```ruby
# frozen_string_literal: true

module GitContext
  module RepoAudit
    module Sections
      # Lists tracked files that match common-offender or secret-shaped
      # patterns. These are files already committed that probably shouldn't
      # be — remediation is `git rm --cached <path>` plus a .gitignore entry.
      class TrackedSecrets
        def title
          "Tracked secrets"
        end

        def render(git)
          patterns = Offenders.all_patterns + Offenders::SECRET_PATTERNS
          flagged = git.ls_files.select do |path|
            patterns.any? { |p| Offenders.matches?(path, p) }
          end

          return "No tracked secrets\n" if flagged.empty?

          lines = flagged.map do |path|
            "- #{path}  (remediate: git rm --cached #{path} && add to .gitignore)"
          end
          lines.join("\n") + "\n"
        end
      end
    end
  end
end
```

- [ ] **Step 4: Run tests**

```bash
bundle exec rake test TEST=test/repo_audit/sections/tracked_secrets_test.rb
bundle exec rake test
```

Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "Add RepoAudit::Sections::TrackedSecrets"
```

---

## Task 9: Add RepoAudit::Sections::GitignoreGaps

**Files:**
- Create: `lib/git_context/repo_audit/sections/gitignore_gaps.rb`
- Create: `test/repo_audit/sections/gitignore_gaps_test.rb`

- [ ] **Step 1: Write failing test**

Create `test/repo_audit/sections/gitignore_gaps_test.rb`:

```ruby
# frozen_string_literal: true

require "test_helper"

class GitignoreGapsSectionTest < Minitest::Test
  include TempRepo

  def test_title
    assert_equal "Gitignore gaps", GitContext::RepoAudit::Sections::GitignoreGaps.new.title
  end

  def test_flags_unignored_env_file_in_working_tree
    in_temp_repo do |dir|
      write_file(".env", "SECRET=1")

      out = GitContext::RepoAudit::Sections::GitignoreGaps.new.render(GitContext::Git.new(dir))
      assert_match(/env_files/, out)
      assert_match(/\.env/, out)
    end
  end

  def test_does_not_flag_already_ignored_file
    in_temp_repo do |dir|
      write_file(".gitignore", ".env\n")
      write_file(".env", "SECRET=1")

      out = GitContext::RepoAudit::Sections::GitignoreGaps.new.render(GitContext::Git.new(dir))
      refute_match(/^- \.env$/, out)
    end
  end

  def test_flags_node_modules_directory_contents
    in_temp_repo do |dir|
      write_file("node_modules/lib/a.js", "x")

      out = GitContext::RepoAudit::Sections::GitignoreGaps.new.render(GitContext::Git.new(dir))
      assert_match(/dep_dirs/, out)
      assert_match(%r{node_modules/}, out)
    end
  end

  def test_none_marker_when_clean
    in_temp_repo do |dir|
      write_file("app.rb", "x")

      out = GitContext::RepoAudit::Sections::GitignoreGaps.new.render(GitContext::Git.new(dir))
      assert_match(/No gaps found/, out)
    end
  end

  def test_groups_findings_by_category
    in_temp_repo do |dir|
      write_file(".env", "x")
      write_file("errors.log", "x")

      out = GitContext::RepoAudit::Sections::GitignoreGaps.new.render(GitContext::Git.new(dir))
      assert_match(/env_files:/, out)
      assert_match(/build_runtime:/, out)
    end
  end

  def test_skips_dot_git_directory
    in_temp_repo do |dir|
      # .git/* should never be walked — if it were, the index file would
      # match "*.log"? No, but .git/index etc. could trip other matchers
      # in the future. This test guards against that regression.
      out = GitContext::RepoAudit::Sections::GitignoreGaps.new.render(GitContext::Git.new(dir))
      refute_match(/\.git\//, out)
    end
  end
end
```

- [ ] **Step 2: Confirm failing**

```bash
bundle exec rake test TEST=test/repo_audit/sections/gitignore_gaps_test.rb
```

Expected: failures.

- [ ] **Step 3: Implement the section**

Create `lib/git_context/repo_audit/sections/gitignore_gaps.rb`:

```ruby
# frozen_string_literal: true

require "find"

module GitContext
  module RepoAudit
    module Sections
      # Reports paths in the working tree that match common-offender patterns
      # and are NOT currently covered by .gitignore. Groups findings by
      # offender category.
      class GitignoreGaps
        def title
          "Gitignore gaps"
        end

        def render(git)
          findings = scan(git)
          return "No gaps found\n" if findings.empty?

          format(findings)
        end

        private

        def scan(git)
          grouped = Hash.new { |h, k| h[k] = [] }

          walk(git.repo_path).each do |relative_path|
            category = classify(relative_path)
            next unless category
            next if git.ignored?(relative_path)

            grouped[category] << relative_path
          end

          grouped
        end

        def walk(root)
          paths = []
          Find.find(root) do |path|
            base = File.basename(path)
            if File.directory?(path) && base == ".git"
              Find.prune
            end
            next if path == root

            rel = path.sub(%r{\A#{Regexp.escape(root)}/?}, "")
            paths << (File.directory?(path) ? "#{rel}/" : rel)
          end
          paths
        end

        def classify(path)
          Offenders::CATEGORIES.each do |category, patterns|
            return category if patterns.any? { |p| Offenders.matches?(path, p) }
          end
          nil
        end

        def format(grouped)
          grouped.map do |category, paths|
            unique = paths.uniq.sort
            "#{category}:\n" + unique.map { |p| "- #{p}" }.join("\n") + "\n"
          end.join("\n")
        end
      end
    end
  end
end
```

- [ ] **Step 4: Run tests**

```bash
bundle exec rake test TEST=test/repo_audit/sections/gitignore_gaps_test.rb
bundle exec rake test
```

Expected: all pass. If `test_flags_node_modules_directory_contents` fails because `ignored?` is called on "node_modules/" (with trailing slash) and git says it's not ignored (since nothing is), that matches — section should still flag it. If there's a mismatch, adjust so `ignored?` is called on a non-trailing-slash version of the path.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "Add RepoAudit::Sections::GitignoreGaps"
```

---

## Task 10: Add RepoAudit::Preset and wire into CLI

**Files:**
- Create: `lib/git_context/repo_audit/sections.rb`
- Create: `lib/git_context/repo_audit/preset.rb`
- Create: `test/repo_audit/preset_test.rb`
- Modify: `lib/git_context/repo_audit.rb` (require new files)
- Modify: `lib/git_context/cli.rb` (register `repo-audit` preset)

- [ ] **Step 1: Create `lib/git_context/repo_audit/sections.rb`**

```ruby
# frozen_string_literal: true

module GitContext
  module RepoAudit
    module Sections
    end
  end
end

require "git_context/repo_audit/sections/gitignore_gaps"
require "git_context/repo_audit/sections/tracked_secrets"
require "git_context/repo_audit/sections/missing_standard_files"
```

- [ ] **Step 2: Write failing test for Preset**

Create `test/repo_audit/preset_test.rb`:

```ruby
# frozen_string_literal: true

require "test_helper"

class RepoAuditPresetTest < Minitest::Test
  def test_name_is_repo_audit
    assert_equal "repo-audit", GitContext::RepoAudit::Preset.new.name
  end

  def test_default_tokens_cover_all_three_sections
    preset = GitContext::RepoAudit::Preset.new
    assert_equal %w[gitignore_gaps tracked_secrets missing_standard_files].sort,
                 preset.default_tokens.sort
  end

  def test_sections_returns_instances
    sections = GitContext::RepoAudit::Preset.new.sections
    assert_equal 3, sections.size
    sections.each { |s| assert_respond_to s, :title }
    sections.each { |s| assert_respond_to s, :render }
  end

  def test_unknown_token_raises
    assert_raises(ArgumentError) { GitContext::RepoAudit::Preset.new.section_for("bogus") }
  end
end
```

- [ ] **Step 3: Implement Preset**

Create `lib/git_context/repo_audit/preset.rb`:

```ruby
# frozen_string_literal: true

module GitContext
  module RepoAudit
    # Default section composition for repo hygiene audit.
    class Preset
      def name
        "repo-audit"
      end

      def default_tokens
        %w[gitignore_gaps tracked_secrets missing_standard_files]
      end

      def available_tokens
        factories.keys
      end

      def section_for(token)
        factory = factories.fetch(token) do
          raise ArgumentError, "unknown section '#{token}' for preset '#{name}'. Available: #{available_tokens.join(', ')}"
        end
        factory.call
      end

      def sections(tokens = default_tokens)
        tokens.map { |t| section_for(t) }
      end

      private

      def factories
        {
          "gitignore_gaps"         => -> { Sections::GitignoreGaps.new },
          "tracked_secrets"        => -> { Sections::TrackedSecrets.new },
          "missing_standard_files" => -> { Sections::MissingStandardFiles.new }
        }
      end
    end
  end
end
```

- [ ] **Step 4: Update `lib/git_context/repo_audit.rb`**

```ruby
# frozen_string_literal: true

module GitContext
  module RepoAudit
  end
end

require "git_context/repo_audit/offenders"
require "git_context/repo_audit/sections"
require "git_context/repo_audit/preset"
```

- [ ] **Step 5: Register preset in CLI**

In `lib/git_context/cli.rb`, update the `PRESETS` constant:

```ruby
    PRESETS = {
      "commit"     => -> { GitContext::Commit::Preset.new },
      "repo-audit" => -> { GitContext::RepoAudit::Preset.new }
    }.freeze
```

- [ ] **Step 6: Add CLI integration test**

Append to `test/cli_test.rb`:

```ruby
class CLIRepoAuditTest < Minitest::Test
  include TempRepo

  def test_runs_repo_audit_preset
    in_temp_repo do |dir|
      write_file(".env", "x")

      out = StringIO.new
      GitContext::CLI.new(argv: ["repo-audit", "--repo", dir], stdout: out).run

      assert_match(/## Gitignore gaps/, out.string)
      assert_match(/## Tracked secrets/, out.string)
      assert_match(/## Missing standard files/, out.string)
      assert_match(/\.env/, out.string)
    end
  end

  def test_repo_audit_list_sections
    out = StringIO.new
    GitContext::CLI.new(argv: ["repo-audit", "--list-sections"], stdout: out).run

    assert_match(/gitignore_gaps/, out.string)
    assert_match(/tracked_secrets/, out.string)
    assert_match(/missing_standard_files/, out.string)
  end
end
```

- [ ] **Step 7: Run tests**

```bash
bundle exec rake test
```

Expected: full suite passes.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "Add RepoAudit::Preset and wire repo-audit into CLI"
```

---

## Task 11: Version bump and README rewrite

**Files:**
- Modify: `lib/git_context/version.rb`
- Modify: `README.md`

- [ ] **Step 1: Bump version**

Replace `lib/git_context/version.rb`:

```ruby
# frozen_string_literal: true

module GitContext
  VERSION = "0.2.0"
end
```

- [ ] **Step 2: Rewrite README**

Replace `README.md`:

```markdown
# git-context

Composable gem for gathering structured git state and emitting it as context —
for Claude Code plugins, other AI tools, or humans.

Each "context type" is a submodule (`GitContext::Commit`, `GitContext::RepoAudit`)
with its own preset (default sections) and sections. Reports compose sections
via duck typing.

## Install

```ruby
gem "git-context"
```

Or:

```
gem install git-context
```

## CLI

```
git-context <preset> [options]

Presets:
  commit        Pre-commit snapshot (status, diffs, log, file history, untracked)
  repo-audit    Repo hygiene check (gitignore gaps, tracked secrets, missing files)

Options:
  --repo PATH           Repo path (default: cwd)
  --only a,b,c          Run only these sections (overrides preset)
  --add a,b             Add sections to the preset
  --skip a,b            Remove sections from the preset
  --list-sections       Print available sections for the preset and exit
```

Examples:

```
git-context commit
git-context commit --skip staged_diff,unstaged_diff
git-context repo-audit --repo ~/code/myproj
git-context repo-audit --only gitignore_gaps
git-context commit --list-sections
```

## Library

```ruby
require "git_context"

git = GitContext::Git.new("/path/to/repo")
sections = GitContext::Commit::Preset.new.sections
puts GitContext::Report.new(git: git, sections: sections).to_s
```

Build your own composition:

```ruby
sections = [
  GitContext::Commit::Sections::Status.new,
  GitContext::RepoAudit::Sections::GitignoreGaps.new
]
puts GitContext::Report.new(git: git, sections: sections).to_s
```

## Architecture

- `GitContext::Report` — composes sections; no knowledge of git internals.
- `GitContext::Git` — the only object that shells out to `git`.
- Sections — duck-typed objects implementing `#title` and `#render(git)`.
- Presets — objects returning an instantiated `sections` array and a
  token↔class map.

See `docs/standards/` for project conventions and `docs/superpowers/` for
design decisions.

## Development

```
bundle install
bundle exec rake test
```
```

- [ ] **Step 3: Run full test suite**

```bash
bundle exec rake test
```

Expected: all pass.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "Bump to 0.2.0 and rewrite README for git-context"
```

---

## Self-review notes

- **Spec coverage:** Architecture (Task 3), CLI surface (Task 4), RepoAudit sections (Tasks 7–9), Offenders (Task 5), Preset pattern (Tasks 3, 10), standards docs + CLAUDE.md (Task 1), rename mechanics (Task 2), version bump + README (Task 11). All covered.
- **Type consistency:** Preset API is identical between `Commit::Preset` and `RepoAudit::Preset` (`#name`, `#default_tokens`, `#available_tokens`, `#section_for`, `#sections`). `Git#repo_path` introduced in Task 7 used again in Tasks 8–9.
- **Task independence:** Each task ends with a green test suite and a commit. Tasks 7, 8, 9 are independent sections; could in principle parallelize, but sequential keeps the Offenders matching behavior testable in one section before extending to others.
- **Ordering dependency note:** Task 7 introduces `Git#repo_path`; Tasks 8–9 depend on it indirectly (sections use it via `git.repo_path`). If Tasks 8–9 were done before 7, the rename step belongs in the first section task that needs it. Current ordering is safe.
