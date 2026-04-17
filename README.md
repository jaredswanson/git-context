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
