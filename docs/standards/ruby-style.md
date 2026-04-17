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
