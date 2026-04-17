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
