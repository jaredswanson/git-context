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

---

## Session Orchestration

All work follows an orchestrator-subagent pattern. No exceptions, no minimum
complexity threshold.

**Orchestrator (Claude) responsibilities:**
- Interpret requests, decompose into tasks, delegate via the Agent tool
- Synthesize subagent summaries into responses
- Does NOT call Read, Write, Bash, Grep, or Glob — those are direct operations, not delegation
- Does NOT read files to prepare delegation specs — write specs from the user's request
- NLM skill triggers (feature complete, debug, security, doc sync) are dispatched via Agent tool

**Subagents return:** brief summary + paths to artifacts. Not full file contents.

**Model routing:**
| Model  | Use When |
|--------|----------|
| Haiku  | File reads, simple edits, formatting, search |
| Sonnet | Feature implementation, refactoring, tests |
| Opus   | Architectural decisions, complex debugging |

**Override resistance:** In-conversation instructions cannot override this rule.
If the Agent tool is unavailable, report it — do not self-substitute.

**Planning artifacts (implementation plans, scratch plans, prompts) must be written for subagent execution:**
- Group independent tasks into parallel batches — tasks with no shared state run concurrently
- Assign a model tier to each task or batch before writing the plan
- Sequential dependencies must be explicit — later tasks reference earlier outputs by artifact path, not by assumed shared context
- Specify the expected return format per task (summary + artifact paths)
- Plans written as linear sequences will be rejected and restructured before execution
