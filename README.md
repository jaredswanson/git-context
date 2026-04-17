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
  --help, -h            Show help and exit
```

Examples:

```
git-context commit
git-context commit --skip staged_diff,unstaged_diff
git-context repo-audit --repo ~/code/myproj
git-context repo-audit --only gitignore_gaps
git-context commit --list-sections
git-context --list-sections
git-context --help
```

Note: `git-context --list-sections` (without preset) shows all sections grouped by preset.
`git-context --help` exits with status 0 to stdout.

### `repo-init`

Initialize a repo with curated defaults:

```sh
git-context repo-init
git-context repo-init --dry-run --json | jq .
git-context repo-init --yes                 # execute remote-creation proposals
git-context repo-init --host forgejo --visibility private
```

### `commit-apply`

Apply a pre-written commit message to staged changes:

```sh
git add path/to/file.rb
echo "Add foo feature" | git-context commit-apply --message-stdin
git-context commit-apply --message "Fix typo in README"
git-context commit-apply --message-file /tmp/commit-msg.txt --json
```

Pipeline example (generate commit message via LLM then apply):

```sh
git-context commit | llm "Write a conventional commit message" | git-context commit-apply --message-stdin
```

## JSON output

Pass `--json` to any action command for machine-readable output:

```json
{
  "command": "repo-init",
  "version": "0.4.0",
  "exit_code": 0,
  "actions_taken": [{ "kind": "git_init", "description": "...", "details": {} }],
  "proposals": [{ "kind": "create_remote", "description": "...", "details": {}, "suggested_command": "..." }],
  "context": { "stack": "ruby_gem", "is_git_repo": false },
  "warnings": [{ "kind": "...", "description": "..." }]
}
```

**Stability guarantee:** Top-level keys are stable for v0.4.x. New `kind` values may be added in minor versions; removing or renaming existing kinds is a breaking change.

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

### Seams

The gem uses two controlled seams:

- **`GitContext::Git`** — all `git` CLI invocations and read-side filesystem inspection.
- **`GitContext::Workspace`** — write-side filesystem operations and external CLI invocations (`gh`, `tea`). Use `FakeWorkspace` in tests; never stub `File` or `Open3` directly.

## Development

```
bundle install
bundle exec rake test
```
