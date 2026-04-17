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
