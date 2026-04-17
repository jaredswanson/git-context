# git-context: pivot from commit-context

**Date:** 2026-04-17
**Status:** Design approved, ready for implementation planning
**Target release:** 0.2.0

## Summary

Rename and reposition `commit-context` to `git-context`: a composable gem that
gathers structured git state and emits it as context (primarily for a Claude
Code plugin, secondarily for humans). The commit-context feature becomes one
preset among several. v0.2 adds a second preset — `repo-audit` — to prove the
composition pattern and to replace a lost repo-init workflow.

The gem stays library-first with a thin CLI. Claude Code plugin work lives in
a separate repo and consumes this gem via the CLI.

## Goals

- Establish a composable architecture where each "context type" is a
  self-contained submodule (preset + sections).
- Ship two presets (`commit`, `repo-audit`) to validate that adding a third is
  additive-only.
- Set project standards (Sandi Metz OOP, TDD, Ruby style) in
  `docs/standards/` and reference them from `CLAUDE.md`.
- Produce output readable by both humans and a Claude Code plugin (plain text
  with section headings; format evolution deferred until there's a felt need).

## Non-goals

- Remediation. Sections report; they do not fix.
- Structured/JSON output. `to_s` works for both audiences in v0.2.
- Exit-code-as-linter behavior. Exit 0 always in v0.2.
- Language-specific hygiene checks, git config checks, hooks/CI checks. Deferred.
- Publishing to rubygems.org under the new name. Local use first.

## Architecture

Top-level module `GitContext`. Each context type is a submodule that owns its
own preset and sections. `Report` is a generic composer; `Git` is a shared
collaborator.

```
GitContext
├── Report                       # composes sections, renders output
├── Git                          # git wrapper (existing CommitContext::Git, renamed)
├── CLI                          # parses argv, resolves preset + flags
├── Commit
│   ├── Preset                   # returns default sections array
│   └── Sections::{Status, StagedDiff, UnstagedDiff, RecentLog, FileHistory, UntrackedFiles}
└── RepoAudit
    ├── Preset
    ├── Offenders                # shared list of common-offender patterns
    └── Sections::{GitignoreGaps, TrackedSecrets, MissingStandardFiles}
```

**Section protocol (duck-typed):** any object responding to `#title` and
`#render(git)` is a valid section. `Report` depends on this protocol, not
concrete classes. Each section has its own test and lives under a context-type
submodule.

**Presets as objects:** `Commit::Preset.new.sections` returns an array of
instantiated sections. The CLI and the Ruby API use the same path — CLI flags
build the same array.

## CLI surface

**Binary:** `git-context` (replaces `commit_context`).

```
git-context <preset> [options]

Presets:
  commit        Pre-commit snapshot
  repo-audit    Repo hygiene check

Options:
  --repo PATH           Repo path (default: cwd)
  --only a,b,c          Run only these sections (overrides preset)
  --add a,b             Add sections to the preset
  --skip a,b            Remove sections from the preset
  --list-sections       Print available sections for the preset and exit
  --help
```

**Section tokens:** snake_case, mapped to section classes under the chosen
preset's namespace. Unknown tokens error with a "did you mean…" suggestion.

**Flag precedence:** `--only` replaces the preset entirely. Otherwise start
from preset, apply `--skip`, then `--add`.

**Exit codes:** `0` always. Findings go in the output body, not the exit code.
A `--fail-on=findings` flag can be added later without breaking callers.

**Ruby API:**

```ruby
require "git_context"

git = GitContext::Git.new("/path/to/repo")
sections = GitContext::Commit::Preset.new.sections
puts GitContext::Report.new(git: git, sections: sections).to_s
```

## RepoAudit sections

All three are read-only. Output is human-readable text with a section heading
the plugin can split on.

### `GitignoreGaps`

Working-tree paths that match a common-offender pattern and are NOT currently
gitignored. Walks the tree respecting current `.gitignore`, filters against
the shared `Offenders` list, reports matches grouped by category. Empty →
"No gaps found."

### `TrackedSecrets`

Files already tracked by git (via `git ls-files`) that match the offenders
list plus secret-shaped patterns (`*.pem`, `*.key`, `id_rsa*`, `*credentials*`,
`*secret*`). Distinct from gaps: these are already committed and need
`git rm --cached` + gitignore. Output includes a remediation hint per file.

### `MissingStandardFiles`

Checks case-insensitive presence of `README*`, `LICENSE*`, `.gitignore`.
Reports which are missing. Empty → "All standard files present."

### `Offenders` (shared)

```ruby
GitContext::RepoAudit::Offenders
```

Single source of truth for common-offender patterns. Categories:

- Env files: `.env`, `.env.*`
- Dep dirs: `node_modules/`, `vendor/bundle/`
- OS/editor cruft: `.DS_Store`, `.idea/`, `.vscode/`, `*.swp`
- Build/runtime: `tmp/`, `log/`, `*.log`, `coverage/`
- DBs: `*.sqlite3`

Internal constant/YAML, easy to extend. No user config file in v0.2.

## Repo layout

```
git-context/
├── CLAUDE.md
├── README.md
├── git-context.gemspec
├── exe/git-context
├── lib/
│   ├── git_context.rb
│   └── git_context/
│       ├── report.rb
│       ├── git.rb
│       ├── cli.rb
│       ├── commit/
│       │   ├── preset.rb
│       │   └── sections/…
│       └── repo_audit/
│           ├── preset.rb
│           ├── offenders.rb
│           └── sections/…
├── test/
│   └── git_context/…          # mirrors lib/
└── docs/
    ├── standards/
    │   ├── oop-principles.md
    │   ├── tdd-workflow.md
    │   └── ruby-style.md
    └── superpowers/
        └── specs/             # this doc lives here
```

## Standards docs

Each short, opinionated, the user's own words. Pointers to Sandi Metz
(POODR, 99 Bottles) rather than textbook restatement.

- **`oop-principles.md`** — small objects, single responsibility, dependency
  injection, duck typing, "ask for what you need" via constructor.
- **`tdd-workflow.md`** — red-green-refactor, test structure conventions, what
  to mock vs. not (don't mock what you don't own; use the real `Git` against a
  fixture repo).
- **`ruby-style.md`** — naming, file organization, when to extract a class,
  when a method is doing too much.

## CLAUDE.md

1-paragraph project summary. Before writing code, read the three standards
docs. Section protocol rule (duck typing + own test + submodule placement).
Test command, lint command.

## Rename mechanics

- Gem name: `commit-context` → `git-context`.
- Top-level module: `CommitContext` → `GitContext`.
- Existing `Sections::*` classes move to `GitContext::Commit::Sections::*`.
- `Report` stays at top level (generic composer).
- `Git` stays at top level (shared collaborator).
- Binary: `exe/commit_context` → `exe/git-context`; command name
  `commit_context` → `git-context`.
- Bump to `0.2.0`.
- Delegate file-by-file move + namespace updates to a subagent (sonnet/haiku)
  once the implementation plan is written.

## Testing approach

- TDD for all new code (RepoAudit sections, CLI arg parsing, Offenders).
- Existing Commit sections keep their tests; update namespaces only.
- Sections test against real `Git` instances operating on fixture repos
  (tmp-dir clones or scripted `git init` + commits). Don't mock `Git`.
- CLI tested via its public entry point with argv arrays; assert on the
  resolved sections array and exit code.

## Open questions (deferred, not blocking)

- Structured output format (JSON/markdown) — wait for plugin to feel the pain.
- Large-file check (#3 from audit candidates) — wait for a real case.
- Publishing to rubygems under new name — local use first.
- Config file for custom offenders — not needed until someone wants it.
