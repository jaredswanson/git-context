# git-context v0.4.0 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan. Every task below is written for subagent delegation: each lists files touched, a model tier, acceptance criteria, test strategy (TDD cadence), explicit dependencies by artifact path, and an expected return format.

**Goal:** Ship v0.4.0 of `git-context` with two new capabilities that let a Claude Code plugin drive the gem as a structured-output tool:

- **F.** `git-context repo-init` — pre-flight audit, auto-apply safe defaults (`git init`, curated `.gitignore` append, initial commit when brand new), heuristic LICENSE/remote-visibility decision, and a *proposal* path for state-changing actions (LICENSE creation, remote creation, push).
- **G.** `git-context commit-apply` — accept a pre-written commit message on stdin (or via flag) and perform the commit against already-staged changes only. Never `git add -A`.
- **H.** Structured JSON output (`--json`) for both new commands (and retrofitted for existing commands where cheap), shape `{ actions_taken, proposals, context, warnings }`, each entry with `kind`, `description`, `details`, and (for proposals) `suggested_command`.
- **I.** A second seam `GitContext::Workspace` for filesystem *writes* and non-git external CLI invocations (`gh`, `tea`). `Git` remains the read/shell seam for git itself; `Workspace` owns everything else. One-seam principle preserved by *category*: one seam per concern (git vs. filesystem/external-CLI).
- **J.** Curated gitignore pattern data in `lib/git_context/repo_init/gitignore_patterns/*.rb` (one constant per stack), stack detection in a `StackDetector` object.

**Baseline:** branch `main`, HEAD at v0.3.0 tag. All tasks end green; no task may be committed with a red suite.

**Spec references (authoritative):**

- `docs/standards/oop-principles.md` — one-seam (per category), duck typing, ask-for-what-you-need.
- `docs/standards/tdd-workflow.md` — red/green/refactor; `FakeGit` + new `FakeWorkspace` for sections, `TempRepo` only for real-seam tests.
- `docs/standards/ruby-style.md` — namespace/file layout, `frozen_string_literal`, kwargs.
- `CLAUDE.md` — planning artifacts must be parallel-batched with model tiers; orchestrator-subagent pattern.
- `docs/superpowers/plans/2026-04-17-git-context-0.3.0.md` — structural reference for plan shape.

**Every task returns:** one-paragraph summary + list of artifact paths (files created/modified/deleted) + test command output confirmation. Subagents must NOT dump file contents back; the orchestrator reads artifacts if needed.

---

## Naming decision: `commit-apply`, not `commit --execute`

Recommend a new verb `commit-apply` over overloading `commit`. Justification:

1. `commit` today is a *read* operation (emits context); conflating read/write in one verb violates ask-for-what-you-need and makes the JSON contract schizophrenic (the `context` key would be meaningful or empty depending on a flag).
2. Shell/pipeline ergonomics: `git-context commit | llm | git-context commit-apply --message-stdin` is a natural pipeline; `git-context commit | llm | git-context commit --execute --message-stdin` reads as self-contradictory.
3. The `CLI::PRESETS` map is preset-oriented; `commit-apply` is not a preset (it has no sections). Keeping the preset map clean is cheaper than carving out an exception.

`commit-apply` registers as a top-level verb alongside presets via a new `CLI::COMMANDS` map (presets become one kind of command).

---

## JSON output contract

All `--json` output is a single JSON object emitted to stdout. Human output is suppressed when `--json` is set (warnings and errors still go to stderr as plain text for shell visibility; they are ALSO reflected in the JSON `warnings` array).

```json
{
  "command": "repo-init",
  "version": "0.4.0",
  "exit_code": 0,
  "actions_taken": [
    {
      "kind": "git_init",
      "description": "Initialized empty git repository",
      "details": { "branch": "main" }
    },
    {
      "kind": "gitignore_append",
      "description": "Appended 12 patterns for stack 'ruby_gem'",
      "details": { "stack": "ruby_gem", "patterns_added": ["*.gem", "/pkg/", "..."], "patterns_skipped": ["/tmp/"] }
    },
    {
      "kind": "initial_commit",
      "description": "Created initial commit",
      "details": { "sha": "abc123", "files": [".gitignore"] }
    }
  ],
  "proposals": [
    {
      "kind": "create_license",
      "description": "Add MIT LICENSE (heuristic: gemspec present)",
      "details": { "license": "MIT", "holder": "jared", "year": 2026 },
      "suggested_command": "git-context repo-init --yes"
    },
    {
      "kind": "create_remote",
      "description": "Create public GitHub repo and add as origin",
      "details": { "host": "github", "visibility": "public", "name": "commit-context" },
      "suggested_command": "gh repo create commit-context --public --source=. --remote=origin --push"
    }
  ],
  "context": {
    "stack": "ruby_gem",
    "is_git_repo": false,
    "has_commits": false,
    "likely_open_source": true,
    "detected_signals": ["gemspec:git-context.gemspec"],
    "audit_findings": { "<preset-token>": "<raw section render output>" }
  },
  "warnings": [
    { "kind": "existing_license", "description": "LICENSE already exists; skipped" }
  ]
}
```

For `commit-apply`:

```json
{
  "command": "commit-apply",
  "version": "0.4.0",
  "exit_code": 0,
  "actions_taken": [
    {
      "kind": "commit",
      "description": "Committed 3 staged files",
      "details": { "sha": "def456", "files": ["a.rb", "b.rb", "c.rb"], "message_first_line": "Add foo" }
    }
  ],
  "proposals": [],
  "context": { "had_staged_changes": true, "had_unstaged_changes": true },
  "warnings": [
    { "kind": "unstaged_changes_left", "description": "3 files have unstaged changes (not committed)" }
  ]
}
```

**Stability guarantee:** The top-level keys (`command`, `version`, `exit_code`, `actions_taken`, `proposals`, `context`, `warnings`) are stable for v0.4.x. New `kind` values may be added in minor versions; removing or renaming is a breaking change.

**Consumer contract:** The Claude Code plugin shells out, reads stdout, `JSON.parse`s, and must tolerate unknown `kind` values gracefully.

---

## Task graph overview

```
Batch 1 (parallel — foundation, no cross-dependencies):
    ├── Task F1: Workspace seam (filesystem writes + gh/tea invocations)
    ├── Task F2: StackDetector + gitignore pattern data
    ├── Task F3: JSON emitter (shared, used by F5/G1)
    └── Task F4: CLI top-level command dispatch refactor

Batch 2 (parallel — builds on Batch 1):
    ├── Task F5: RepoInit command (uses F1/F2/F3/F4)
    └── Task G1: CommitApply command (uses F1/F3/F4)

Batch 3 (integration, after Batches 1+2 green):
    └── Task H: Version bump 0.4.0 + README + CHANGELOG
```

Total tasks: **7** (F1, F2, F3, F4, F5, G1, H). Batch 1's four tasks are fully independent (disjoint files). Batch 2's two tasks each consume Batch 1 outputs but do not overlap with each other.

---

## Task F1 — `GitContext::Workspace` seam

**Model:** Sonnet. *Rationale:* new seam class with external-CLI invocations; TDD against real temp dirs plus a fake for downstream consumers.

**Files touched:**

- Create: `lib/git_context/workspace.rb`
- Modify: `lib/git_context.rb` (require new file)
- Create: `test/workspace_test.rb`
- Modify: `test/test_helper.rb` (add `FakeWorkspace`)

**Depends on:** nothing. Runs in parallel with F2/F3/F4.

**Design:**

`GitContext::Workspace` is the second seam. Constructor takes `repo_path`. Public methods (all return structured result objects with `success?`, `output`, `error`; never raise for expected failures):

- `write_file(relative_path, contents, mode: "w")` — writes under `@repo_path`. Raises `ArgumentError` if `relative_path` escapes root.
- `append_file(relative_path, contents)` — appends.
- `file_exists?(relative_path)` — Boolean.
- `read_lines(relative_path)` — Array<String>, or `[]` if absent.
- `run_gh(*args)` — shells out to `gh` with `Dir.chdir(@repo_path)`. Returns a `Workspace::Result` struct.
- `run_tea(*args)` — same for `tea`.
- `which(binary)` — Boolean: is the binary on `PATH`?

**Rationale for separate seam (not method-sprawl on `Git`):** `Git` is about `git` CLI invocations and read-side filesystem inspection. Write-side filesystem and *other* external CLIs (`gh`, `tea`) are a different concern. Two named seams remain clearer than a unified `System` god-object, and the one-seam rule is preserved per-concern. Downstream objects take both `git:` and `workspace:` as explicit dependencies — the seams are still narrow, just split by concern. Document this rationale in a comment atop `workspace.rb`.

**`FakeWorkspace` contract** (in `test_helper.rb`): mirrors `Workspace` interface. `write_file` / `append_file` record into an in-memory `@writes` hash. `read_lines` / `file_exists?` read from canned `@files`. `run_gh` / `run_tea` return canned `Result` objects from a call-pattern → result map. `which` returns canned hash default-true.

**Acceptance criteria:**

- `workspace_test.rb` covers: `write_file` creates a file; `append_file` appends; path-escape raises; `run_gh` with a missing binary returns a failed `Result` (use `which` to check in the method). `run_gh` success path uses a stub command (e.g., `gh --version`) only if `gh` is on PATH, otherwise skip with a pending marker.
- `FakeWorkspace` supports all methods consumed in F5/G1.
- Full suite green.

**TDD cadence:** RED — write `workspace_test.rb` with 6–8 tests. GREEN — implement. REFACTOR — extract `Result` struct if logic repeats.

**Test command:** `bundle exec rake test TEST=test/workspace_test.rb` then full `bundle exec rake test`.

**Return format:** summary + artifact paths + green confirmation.

---

## Task F2 — `StackDetector` + curated gitignore pattern data

**Model:** Sonnet. *Rationale:* heuristic detection with a handful of branches; data files are trivial but detector logic needs tests.

**Files touched:**

- Create: `lib/git_context/repo_init.rb` (module shell)
- Create: `lib/git_context/repo_init/stack_detector.rb`
- Create: `lib/git_context/repo_init/gitignore_patterns.rb` (module, requires the per-stack files)
- Create: `lib/git_context/repo_init/gitignore_patterns/ruby_gem.rb`
- Create: `lib/git_context/repo_init/gitignore_patterns/node.rb`
- Create: `lib/git_context/repo_init/gitignore_patterns/python.rb`
- Create: `lib/git_context/repo_init/gitignore_patterns/claude_plugin.rb`
- Create: `lib/git_context/repo_init/gitignore_patterns/generic.rb`
- Create: `test/repo_init/stack_detector_test.rb`
- Create: `test/repo_init/gitignore_patterns_test.rb`
- Modify: `lib/git_context.rb` (require `repo_init`)

**Depends on:** nothing. Runs in parallel with F1/F3/F4.

**Design:**

`StackDetector` takes `git:` (for `entries`) and detects stack(s):

- `ruby_gem` — any `*.gemspec` at root
- `claude_plugin` — `.claude-plugin/` directory present
- `node` — `package.json` present
- `python` — `pyproject.toml` or `setup.py` present
- `generic` — fallback

Returns `Array<Symbol>` in detection order. Multiple stacks possible (a gem that's also a Claude plugin).

`#likely_open_source?` returns true if ANY of: gemspec present, `.claude-plugin/` manifest present, `package.json` with `"private": false` (or missing `private` key). Returns a small struct `{ value: Bool, signals: Array<String> }` so RepoInit can emit signals in JSON `context`.

Each pattern file defines `GitContext::RepoInit::GitignorePatterns::RUBY_GEM = [...].freeze` — an array of strings. `GitignorePatterns.for(stack)` returns the patterns; `GitignorePatterns.merged(stacks)` returns the deduped union.

Pattern content (initial cut — subagent may expand after skimming `github/gitignore` conventions, but keep lists tight):

- `ruby_gem`: `*.gem`, `/pkg/`, `/doc/`, `/tmp/`, `/.bundle/`, `Gemfile.lock` (gemspec-project convention), `/coverage/`, `/.yardoc/`
- `node`: `node_modules/`, `/dist/`, `/build/`, `.env`, `.env.local`, `npm-debug.log*`, `.pnpm-debug.log*`
- `python`: `__pycache__/`, `*.pyc`, `/dist/`, `/build/`, `*.egg-info/`, `.venv/`, `venv/`, `.pytest_cache/`, `.ruff_cache/`
- `claude_plugin`: `.claude/local-settings.json`, `.claude/state/`
- `generic`: `.DS_Store`, `*.swp`, `*.log`, `/.idea/`, `/.vscode/`

**Acceptance criteria:**

- `stack_detector_test.rb` covers each single-stack case, the multi-stack case (gem + claude_plugin), and `likely_open_source?` for: gemspec→true, claude_plugin→true, `package.json` private:false→true, `package.json` private:true→false, none→false. Uses `FakeGit` with canned `entries` and `read_file`.
- `gitignore_patterns_test.rb` asserts `GitignorePatterns.for(:ruby_gem)` returns an array containing `*.gem`; `.merged([:ruby_gem, :generic])` returns dedup'd union.
- Full suite green.

**TDD cadence:** RED — write detector tests first with `FakeGit`. GREEN — implement. REFACTOR — collapse duplicated signal-recording logic if it emerges.

**Test command:** `bundle exec rake test TEST=test/repo_init/` then full suite.

**Return format:** summary + artifact paths + green confirmation.

---

## Task F3 — JSON emitter

**Model:** Haiku. *Rationale:* tiny pure-data object with no I/O; the JSON contract is fully specified above.

**Files touched:**

- Create: `lib/git_context/json_report.rb`
- Create: `test/json_report_test.rb`
- Modify: `lib/git_context.rb` (require)

**Depends on:** nothing. Runs in parallel with F1/F2/F4.

**Design:**

`GitContext::JsonReport` is a collector + serializer. Constructor: `command:`, `version:` (defaults to `GitContext::VERSION`). Methods:

- `add_action(kind:, description:, details: {})`
- `add_proposal(kind:, description:, details: {}, suggested_command: nil)`
- `set_context(hash)` / `merge_context(hash)`
- `add_warning(kind:, description:)`
- `to_h` → returns the full hash matching the contract
- `to_json(pretty: false)` → serializes (`JSON.pretty_generate` when `pretty: true`)
- `exit_code` defaults to `0`; `#fail!(code)` sets nonzero

**Acceptance criteria:**

- `json_report_test.rb` covers: empty report produces contract-shaped hash with empty arrays; single action/proposal/warning serialize correctly; `to_json` parses back to equivalent hash; `set_context` replaces, `merge_context` merges.
- Full suite green.

**TDD cadence:** RED — write 5–6 tests. GREEN — implement. No refactor needed.

**Test command:** `bundle exec rake test TEST=test/json_report_test.rb`.

**Return format:** summary + artifact paths + green confirmation.

---

## Task F4 — CLI top-level command dispatch refactor

**Model:** Sonnet. *Rationale:* behavior-preserving refactor of dispatch plus new extension points; OptionParser subtleties.

**Files touched:**

- Modify: `lib/git_context/cli.rb`
- Modify: `test/cli_test.rb`

**Depends on:** nothing. Runs in parallel with F1/F2/F3.

**Problem:** `CLI::PRESETS` assumes every top-level word is a preset. `repo-init` and `commit-apply` are not presets — they have their own argv schema. Current dispatch in `CLI#run` is preset-shaped.

**Design:**

Introduce `CLI::COMMANDS` — a map from command name to a lambda that takes `(argv, stdout, stderr)` and does the work. Preset commands (`commit`, `repo-audit`) delegate to a `PresetCommand` helper that preserves today's behavior exactly. New commands `repo-init` and `commit-apply` are added as stubs in F4 and filled in by F5/G1. In F4, the stubs simply `raise NotImplementedError` but are present in the dispatch table so `--help` and `--list-sections` (no preset) reflect them.

`--help` banner is updated to list all commands and distinguish preset-commands from action-commands:

```
Usage: git-context <command> [options]

Preset commands (read-only, emit context):
  commit
  repo-audit

Action commands:
  repo-init     Initialize a repo with curated defaults
  commit-apply  Commit staged changes with a given message
```

`--list-sections` (no command) still only groups preset-commands.

**Acceptance criteria:**

- Existing CLI tests pass unchanged.
- New test: `test_help_lists_action_commands` asserts `repo-init` and `commit-apply` appear in `--help` output.
- New test: `test_unknown_command_shows_all_commands_in_error` asserts the error message includes both preset and action commands.
- New test: `test_list_sections_without_command_shows_only_preset_commands` — action commands are NOT listed (they have no sections).
- Dispatching `repo-init` or `commit-apply` currently raises `NotImplementedError` (caught and reported with exit 2 and a "not yet implemented" message) — this is a temporary state for F4's sake and will be overwritten by F5/G1.
- Full suite green.

**TDD cadence:** RED — add the four new tests. GREEN — refactor dispatch. REFACTOR — extract `PresetCommand` into its own file if the CLI grows past ~150 lines.

**Test command:** `bundle exec rake test TEST=test/cli_test.rb` then full suite.

**Return format:** summary + artifact paths + green confirmation.

---

## Task F5 — `repo-init` command

**Model:** Opus. *Rationale:* integrates four new components (Workspace, StackDetector, JsonReport, CLI dispatch), implements the heuristic decision tree, and has nontrivial idempotency/safety requirements. Architecturally loaded.

**Files touched:**

- Create: `lib/git_context/repo_init/command.rb`
- Create: `lib/git_context/repo_init/licenses/mit.rb` (MIT template constant)
- Modify: `lib/git_context/cli.rb` (wire `repo-init` dispatch)
- Modify: `lib/git_context/git.rb` (add `init_repo`, `add`, `commit`, `current_branch`, `has_remote?`, `add_remote` — git write methods belong on the git seam)
- Modify: `test/git_test.rb` (tests for the new git write methods against `TempRepo`)
- Modify: `test/test_helper.rb` (extend `FakeGit` with the new methods — canned outputs + call recording)
- Create: `test/repo_init/command_test.rb`

**Depends on:** F1 (Workspace), F2 (StackDetector + patterns), F3 (JsonReport), F4 (CLI dispatch slot).

**Behavior spec:**

Inputs: `--host github|forgejo`, `--visibility public|private`, `--yes`, `--json`, `--dry-run`, `--repo PATH`.

1. **Audit pre-flight.** Instantiate `RepoAudit::Preset` sections, render each against the provided `git`, capture raw output as `context.audit_findings["<token>"] = "<output>"`. This is informational only — does not block.

2. **Auto-apply (always, unless `--dry-run`):**
   - If not a git repo (no `.git/` directory — check via `Workspace#file_exists?(".git")` — subagent: consider a `Git#repo?` helper): `git init -b main`. Record action `git_init`.
   - Detect stack via `StackDetector`. Record `context.stack = stack.first` (primary) and `context.detected_stacks = stacks`.
   - For each pattern in `GitignorePatterns.merged(stacks)`: read existing `.gitignore` (via `Workspace#read_lines`), compute set of missing patterns, append them with a leading header comment `# Added by git-context v0.4.0 (stack: ...)` ONLY if any are missing. Record action `gitignore_append` with `patterns_added` / `patterns_skipped`. Creates `.gitignore` if absent.
   - If repo is brand new (no commits — `git log` fails / `Git#has_commits?` returns false): `git add .gitignore` (only `.gitignore`, not `-A`), `git commit -m "Initial commit"`. Record action `initial_commit`.

3. **Heuristic-default actions (auto-apply unless overridden or `--dry-run`):**
   - LICENSE: if missing AND `StackDetector#likely_open_source?.value == true` AND user did not explicitly pass `--visibility private`: write `LICENSE` (MIT template, year = current year 2026, holder = `git config user.name` via `Git#config_get("user.name")` falling back to the value of `GIT_AUTHOR_NAME` or literal "Copyright Holder"). Stage + amend initial commit only if `initial_commit` was emitted this run; otherwise leave unstaged and record as action `license_created`.
   - If likely-OSS: default host = `github`, default visibility = `public`. Else default host = `forgejo`, default visibility = `private`. Explicit `--host` / `--visibility` flags override.

4. **Proposals (never auto-apply unless `--yes`):**
   - If LICENSE *exists* and its first ~3 lines don't match the detected default (MIT) → proposal `replace_license` with `suggested_command` showing the overwrite command. Never auto-overwrite.
   - If no `origin` remote: proposal `create_remote` with `kind` = `create_remote`, details `{ host, visibility, name }` where name = repo_path basename. `suggested_command`:
     - GitHub: `gh repo create <name> --<visibility> --source=. --remote=origin --push`
     - Forgejo: `tea repos create --name <name> --private=<bool>` followed by `git remote add origin ...` and `git push -u origin main`.
   - If `--yes` is passed: execute the remote-creation proposal via `Workspace#run_gh` or `#run_tea`. On success move the entry from `proposals` to `actions_taken` (kind becomes `remote_created`). On failure: keep in `proposals`, add a warning.

5. **Dry-run:** `--dry-run` converts every would-be action into a proposal (with `suggested_command` being the exact shell that would have run). Pairs well with `--json` for plugin pre-flight.

6. **Output:**
   - Default: human-readable summary listing actions taken, proposals, warnings.
   - `--json`: serialized `JsonReport` to stdout.

**Idempotency:** running `repo-init` twice must be safe. Second run: git already initialized (no action), all patterns already present (no action), LICENSE exists (proposal, not action), remote exists (no proposal). Test this explicitly.

**Safety rails (never violate):**
- Never `git add -A`. Only stage `.gitignore` and (optionally) `LICENSE`.
- Never overwrite existing `.gitignore` (append only); never overwrite existing `LICENSE` (proposal only).
- Never push without `--yes`.
- Never create a remote without `--yes`.

**Acceptance criteria:**

- `command_test.rb` covers: brand-new repo ruby-gem → git_init + gitignore_append + initial_commit + license_created actions; propose-remote when no origin; idempotency (second run is a no-op); `--dry-run` emits no actions, only proposals; `--yes` with canned `FakeWorkspace` gh-success moves proposal to action; `--visibility private --host forgejo` overrides heuristic; existing LICENSE → proposal not overwrite; existing gitignore with some patterns → only missing patterns added.
- `git_test.rb` covers the new write methods: `init_repo`, `add("path")`, `commit(message)`, `has_commits?`, `current_branch`, `add_remote(name, url)`, `has_remote?(name)`.
- Running `git-context repo-init --help` via CLI integration test succeeds with exit 0.
- JSON output passes `JSON.parse` and matches the documented contract shape (test asserts top-level keys).
- Full suite green.

**TDD cadence:**

1. RED — write `Git` write-method tests in `git_test.rb` using `TempRepo`.
2. GREEN — implement `Git` write methods.
3. RED — write `FakeGit` extensions and 10–12 `command_test.rb` tests for each behavior above, with `FakeGit` + `FakeWorkspace`.
4. GREEN — implement `RepoInit::Command`.
5. REFACTOR — extract any action-building helpers; ensure `Command#run` reads top-down as a narrative of the decision tree.

**Test command:** `bundle exec rake test TEST=test/repo_init/command_test.rb`, then `bundle exec rake test TEST=test/git_test.rb`, then full suite.

**Return format:** summary + artifact paths grouped by subtask (Git writes / Command) + green confirmation.

---

## Task G1 — `commit-apply` command

**Model:** Sonnet. *Rationale:* smaller scope than F5, one clear decision path, but writes to the repo and needs tight safety tests.

**Files touched:**

- Create: `lib/git_context/commit_apply.rb`
- Modify: `lib/git_context/cli.rb` (wire `commit-apply` dispatch)
- Create: `test/commit_apply_test.rb`
- Possibly modify: `lib/git_context/git.rb` (add `commit(message)` if not added by F5 — coordinate via F5's interface)
- Modify: `test/test_helper.rb` (extend `FakeGit` to record commit calls) — only if F5 hasn't done so.

**Depends on:** F1 (not strictly — commit-apply uses `Git` only), F3 (JsonReport), F4 (dispatch). If F5 lands first, reuse `Git#commit`; otherwise G1 adds it. Orchestrator coordinates: if F5 and G1 both add `Git#commit` independently, integration step resolves.

**Behavior spec:**

Inputs:
- `--message TEXT` (inline message)
- `--message-file PATH` (read from file)
- `--message-stdin` (read from stdin)
- `--json`
- `--allow-empty` (passthrough to `git commit --allow-empty`)
- `--repo PATH`

Exactly one of the three message sources must be provided. Otherwise exit 2 with clear error.

Flow:
1. Read message from chosen source. Strip trailing newline. Validate non-empty (unless `--allow-empty`).
2. Check staged changes via `Git#diff(staged: true)`. If empty and not `--allow-empty` → exit 1 with warning "No staged changes; nothing to commit."
3. `Git#commit(message)` (which internally uses `git commit -m <msg>` — never `-A`, never `-a`).
4. Record action `commit` with details `{ sha, files, message_first_line }`.
5. Check unstaged changes post-commit (`Git#modified_files` + `Git#untracked_files`). If nonempty, add warning `unstaged_changes_left`.
6. Emit human or JSON output.

**Safety rails:**
- NEVER `git add`. Caller is responsible for staging.
- NEVER `git commit -a` or `-A`.
- `--allow-empty` must be explicit.
- Reject messages that are only whitespace.

**Acceptance criteria:**

- `commit_apply_test.rb` covers: staged changes + inline message → action recorded; no staged changes + no `--allow-empty` → exit 1, warning emitted; `--allow-empty` with no staged changes → commit recorded; message from stdin; message from file; missing message source → exit 2; whitespace-only message → exit 2; unstaged changes remain after commit → warning `unstaged_changes_left`.
- `FakeGit#commit` records the message and returns a canned SHA; `Git#commit` uses real `git commit` against `TempRepo` in `git_test.rb`.
- JSON output passes schema check.
- Full suite green.

**TDD cadence:** RED — tests. GREEN — implement `CommitApply` class and wire into CLI. REFACTOR — extract `MessageSource` resolver if the three input modes bloat the class.

**Test command:** `bundle exec rake test TEST=test/commit_apply_test.rb` then full suite.

**Return format:** summary + artifact paths + green confirmation.

---

## Task H — Version bump + README/CHANGELOG update

**Model:** Haiku. *Rationale:* pure file edits.

**Files touched:**

- Modify: `lib/git_context/version.rb` (`"0.3.0"` → `"0.4.0"`)
- Modify: `README.md` (document `repo-init`, `commit-apply`, `--json` contract, Workspace seam note for contributors)
- Modify: `CHANGELOG.md` (add `## [0.4.0] - 2026-04-17`)

**Depends on:** artifacts from F1–F5 and G1 all committed green.

**Acceptance criteria:**

- `GitContext::VERSION == "0.4.0"`.
- `CHANGELOG.md` under `## [0.4.0]` lists: "Add `repo-init` command with curated gitignore, LICENSE heuristic, and remote-creation proposals", "Add `commit-apply` command for applying pre-generated commit messages to staged changes", "Add `--json` structured output for new commands", "Introduce `GitContext::Workspace` seam for filesystem writes and external CLIs", "Add `StackDetector` for ruby_gem / node / python / claude_plugin / generic stacks".
- `README.md` has a new "JSON output" section documenting the contract top-level shape and stability guarantee.
- `README.md` CLI examples include a `repo-init` walkthrough and a `commit | llm | commit-apply` pipeline example.
- Full suite green (nothing structural should move here).

**TDD cadence:** n/a. Run `bundle exec rake test` as sanity.

**Return format:** summary + artifact paths + green confirmation.

---

## Orchestrator checklist

After Batch 1 (F1/F2/F3/F4) subagents all return green:
- [ ] Verify `git status` is clean on `main` (all four tasks have committed their own work).
- [ ] Run `bundle exec rake test`.
- [ ] Dispatch Batch 2 (F5, G1) in parallel.

After Batch 2 returns green:
- [ ] Verify clean `main`, run full suite.
- [ ] Manually smoke-test in a throwaway temp dir: `cd /tmp && mkdir test-gem && cd test-gem && git-context repo-init --dry-run --json | jq .` — inspect output shape.
- [ ] Smoke-test: `echo "test commit" | git-context commit-apply --message-stdin --json` in a repo with a staged change.
- [ ] Dispatch Task H.
- [ ] Final `bundle exec rake test`.
- [ ] Tag `v0.4.0` if the user requests a release (NOT automatic).
