# git-context v0.3.0 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan. Every task below is written for subagent delegation: each lists files touched, a model tier, acceptance criteria, test strategy (TDD cadence), explicit dependencies by artifact path, and an expected return format.

**Goal:** Ship v0.3.0 of `git-context` addressing four post-v0.2.0 issues uncovered by a live CLI run and code review:

- **A.** `tracked_secrets` false-positives on the gem's own source/test files.
- **B.** `GitignoreGaps` and `MissingStandardFiles` bypass the `Git` seam.
- **C.** `Commit::Preset` and `RepoAudit::Preset` are ~90% duplicated.
- **D.** CLI `--help` / `--list-sections` exit 1, banners print on success paths, and there is no cross-preset discovery.

**Baseline:** branch `main`, HEAD `c0775a8`, 72 tests passing. All tasks end green; no task may be committed with a red suite.

**Spec references (authoritative):**

- `docs/standards/oop-principles.md` — one-seam rule, duck typing.
- `docs/standards/tdd-workflow.md` — red/green/refactor; `FakeGit` for sections, `TempRepo` only for `Git` itself.
- `docs/standards/ruby-style.md` — namespace/file layout, `frozen_string_literal`, kwargs.
- `CLAUDE.md` — planning artifacts must be parallel-batched with model tiers.
- `docs/superpowers/plans/2026-04-17-git-context-pivot.md` — structural reference.

**Every task returns:** one-paragraph summary + list of artifact paths (files created/modified/deleted) + test command output confirmation. Subagents must NOT dump file contents back; the orchestrator reads artifacts if needed.

---

## Task graph overview

```
Batch 1 (parallel — three independent workstreams):
    ├── Task A: Fix tracked_secrets false-positive
    ├── Task C: Extract GitContext::Preset base class
    └── Task D: Fix CLI help / list-sections UX

Batch 2 (sequential internally; parallel with nothing — Task B is monolithic):
    └── Task B: Move filesystem access behind Git seam
             B.1 → B.2 → B.3 → B.4 → B.5
        (intra-task dependency chain; see task body)

Batch 3 (integration, runs after Batches 1 + 2 are all green):
    └── Task E: Version bump to 0.3.0 + README / CHANGELOG update
```

Total tasks: **5** (A, B, C, D, E). Task B has 5 sequential subtasks but is delegated as a single subagent assignment because the intra-dependencies are tight and shared state (new `Git` methods) is used throughout.

**Batches 1 and 2 can run fully in parallel**: Tasks A, B, C, D touch disjoint files (see per-task "Files touched"). Task B modifies `lib/git_context/git.rb`; Task A and Task D do not. Task C does not touch `git.rb` or section files. The merge target of Batch 1 and Batch 2 is a single clean `main` — if any two tasks accidentally converge on a shared file, resolve by serializing in Batch 3's integration step.

**Batch 3** runs only once all prior tasks have committed green.

---

## Task A — Fix `tracked_secrets` false-positive on own source

**Model:** Sonnet. *Rationale:* non-trivial matching-logic change with TDD-driven regression tests; not architectural.

**Files touched:**

- Modify: `lib/git_context/repo_audit/sections/tracked_secrets.rb`
- Modify: `test/repo_audit/sections/tracked_secrets_test.rb`
- Modify: `lib/git_context/repo_audit/offenders.rb` (if the pattern tightening lives there — subagent's judgment)

**Depends on:** nothing. Independent of Tasks B/C/D.

**Problem restated:** The current `render` method flags every `ls_files` entry whose basename matches `*secret*` or `*credentials*`. This catches `lib/git_context/repo_audit/sections/tracked_secrets.rb` and its test. The remediation line tells the user to `git rm --cached` their own source.

**Required new behavior (pick option 1 unless subagent finds it inadequate after reading `Offenders.matches?`):**

1. **Basename tightening (preferred).** Treat `*secret*` / `*credentials*` as matching only basenames where the token appears as a standalone word (bounded by non-alphanum or start/end) AND the extension is not `.rb`, `.py`, `.js`, `.ts`, `.go`, `.md`, `.txt` (source/docs). A filename like `tracked_secrets.rb` has the token `secrets` but `.rb` extension → skip. `secrets.yml`, `my.credentials`, `app-secrets.json` → flag.
2. **Content heuristic fallback.** If option 1 is insufficient (e.g., `secrets.yml` that's a safe template), add a size/content sniff — but avoid this unless the TDD red tests genuinely require it. Prefer the cheaper fix.

**Acceptance criteria:**

- `tracked_secrets.rb` (this gem's own file) is NOT flagged when present in `ls_files`.
- `tracked_secrets_test.rb` is NOT flagged.
- Regression test: `test_does_not_flag_own_source_files` uses `FakeGit` with `ls_files: ["lib/git_context/repo_audit/sections/tracked_secrets.rb", "test/repo_audit/sections/tracked_secrets_test.rb"]` and asserts the output contains `/No tracked secrets/`.
- Regression test: `test_flags_secrets_yml` — `ls_files: ["config/secrets.yml"]` IS flagged.
- Regression test: `test_flags_credentials_json` — `ls_files: ["app.credentials.json"]` IS flagged.
- All existing `tracked_secrets_test.rb` assertions still pass (`.env`, `cert.pem` are still flagged).
- No other section's tests change.

**TDD cadence:**

1. Add the three new tests to `tracked_secrets_test.rb`. Run suite; confirm the two `does_not_flag_own_source` assertions fail and the `flags_secrets_yml` / `flags_credentials_json` pass (existing logic already flags them).
2. Modify matching logic (in `tracked_secrets.rb` or `offenders.rb`) to exclude source extensions.
3. Re-run: all green.
4. Refactor for clarity if the extension-skip list is nontrivial (extract `SOURCE_EXTENSIONS` constant).

**Test command:** `bundle exec rake test TEST=test/repo_audit/sections/tracked_secrets_test.rb` then full `bundle exec rake test`.

**Return format:** summary (1 paragraph) + artifact paths + last line of `rake test` output confirming green.

---

## Task B — Move filesystem access behind the `Git` seam

**Model:** Sonnet. *Rationale:* a seam-compliance refactor with multiple coordinated files; mechanical once shape is clear. Not architectural enough for Opus.

**Files touched:**

- Modify: `lib/git_context/git.rb` (add `walk_working_tree`, `entries`)
- Modify: `lib/git_context/repo_audit/sections/gitignore_gaps.rb` (rewrite `walk`; drop `require "find"`)
- Modify: `lib/git_context/repo_audit/sections/missing_standard_files.rb` (replace `Dir.children` with `git.entries`)
- Modify: `test/test_helper.rb` (extend `FakeGit` with `walk_working_tree`, `entries`, `ls_files`, `ignored?`)
- Modify: `test/repo_audit/sections/gitignore_gaps_test.rb` (migrate off `TempRepo` to `FakeGit`)
- Modify: `test/repo_audit/sections/missing_standard_files_test.rb` (migrate off `TempRepo` to `FakeGit`)
- Modify: `test/git_test.rb` (add one real-repo test covering `walk_working_tree` + `entries`)

**Depends on:** nothing externally. Runs in parallel with A/C/D.

**Intra-task ordering (sequential within this task):**

- **B.1** — Add failing `Git` tests for `walk_working_tree` and `entries` in `test/git_test.rb`. Uses `TempRepo`. Acceptance: tests fail with `NoMethodError`.
- **B.2** — Implement `walk_working_tree` and `entries` on `Git`. Acceptance: B.1 tests pass. Full suite still green (old sections still use `Find`/`Dir.children` directly — no regression).
- **B.3** — Extend `FakeGit` with `walk_working_tree(repo_relative_paths)`, `entries(subpath = ".")`, `ls_files`, `ignored?(path)`. Acceptance: `FakeGit#walk_working_tree` returns injected array; `entries` returns injected children for a given subpath; `ignored?` returns injected hash lookup default-false.
- **B.4** — Rewrite `GitignoreGaps` and `MissingStandardFiles` to call `git.walk_working_tree` / `git.entries`. Drop `require "find"` from `gitignore_gaps.rb`. Drop direct `Dir.children` / `git.repo_path` filesystem access from `missing_standard_files.rb`. Acceptance: both section source files grep-clean for `Find`, `Dir.`, `File.directory?`, `git.repo_path`.
- **B.5** — Migrate `test/repo_audit/sections/gitignore_gaps_test.rb` and `test/repo_audit/sections/missing_standard_files_test.rb` off `TempRepo`. Use `FakeGit.new(walk_working_tree: [...], ignored?: {...})` etc. Keep ONE end-to-end real-repo test in each suite only if the subagent judges it valuable for confidence; otherwise delete. Per `tdd-workflow.md` §"What to mock", real-repo tests belong in `git_test.rb`. Acceptance: neither section test file includes `TempRepo`; full suite green.

**Contract for new `Git` methods:**

```ruby
# Returns an Array<String> of repo-relative paths. Directories get a trailing
# "/". The ".git" directory is pruned. Order is not guaranteed.
def walk_working_tree
  ...
end

# Returns Dir.children(File.join(@repo_path, subpath)). Subpath is ".". No
# filtering, no sorting. Raises if subpath is outside the repo.
def entries(subpath = ".")
  ...
end
```

**Acceptance criteria (task-level):**

- `lib/git_context/repo_audit/sections/gitignore_gaps.rb` does not `require "find"` and does not reference `Find`, `Dir.`, `File.directory?`, or `git.repo_path`.
- `lib/git_context/repo_audit/sections/missing_standard_files.rb` does not reference `Dir.`, `File.`, or `git.repo_path`.
- `test/git_test.rb` has one new test class (or two `test_` methods) covering `walk_working_tree` (tracked + untracked + `.git` pruned) and `entries`.
- `test/test_helper.rb` `FakeGit` supports the four new methods.
- Section tests for `GitignoreGaps` and `MissingStandardFiles` use `FakeGit` (no `TempRepo` include).
- Full suite green.

**TDD cadence per subtask:** Each subtask is its own red-green-refactor pass. B.5's test rewrite must go RED first (tests passing with new FakeGit stubs would mean the rewrite didn't actually change anything).

**Test command after each subtask:** targeted file, then `bundle exec rake test`.

**Return format:** summary + artifact paths grouped by subtask + final `rake test` green line.

---

## Task C — Extract `GitContext::Preset` base class

**Model:** Haiku. *Rationale:* small mechanical DRY extraction; two ~45-line files collapsing to shared parent + two tiny subclasses. No design decisions.

**Files touched:**

- Create: `lib/git_context/preset.rb`
- Modify: `lib/git_context/commit/preset.rb`
- Modify: `lib/git_context/repo_audit/preset.rb`
- Modify: `lib/git_context.rb` (add `require "git_context/preset"` before `commit`/`repo_audit` requires)

**Depends on:** nothing. Independent of Tasks A/B/D.

**Design:**

```ruby
# lib/git_context/preset.rb
module GitContext
  # Abstract base: default-token composition with a factory map.
  # Subclasses implement #name, #default_tokens, and #factories (private).
  class Preset
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

    def name
      raise NotImplementedError
    end

    def default_tokens
      raise NotImplementedError
    end

    private

    def factories
      raise NotImplementedError
    end
  end
end
```

Subclasses (`Commit::Preset < GitContext::Preset`, `RepoAudit::Preset < GitContext::Preset`) retain only `#name`, `#default_tokens`, and the private `#factories`.

**Acceptance criteria:**

- `lib/git_context/commit/preset.rb` is under 25 lines.
- `lib/git_context/repo_audit/preset.rb` is under 20 lines.
- Both inherit from `GitContext::Preset`.
- Existing preset tests (`test/commit/preset_test.rb`, `test/repo_audit/preset_test.rb`) pass unchanged.
- Full suite green.

**TDD cadence:** refactor under existing tests — no new tests required (per task brief). If the subagent spots an uncovered branch (e.g., calling `sections` with an empty array), add one test; otherwise proceed.

**Test command:** `bundle exec rake test`.

**Return format:** summary + artifact paths + green confirmation.

---

## Task D — Fix CLI `--help` / `--list-sections` and add cross-preset discovery

**Model:** Sonnet. *Rationale:* three behavioral changes with tested exit codes and output contracts; OptionParser quirks make it easy to get wrong.

**Files touched:**

- Modify: `lib/git_context/cli.rb`
- Modify: `test/cli_test.rb`

**Depends on:** nothing. Independent of Tasks A/B/C.

**Current bugs (live-run evidence):**

1. `git-context --help` exits **1** and prints the OptionParser banner from the `preset.nil? || preset.start_with?("-")` guard, which treats `--help` as "missing preset". Should exit **0** and print help.
2. `git-context --list-sections` (no preset) exits **1** for the same reason. Should either (a) list all sections across all presets, grouped by preset, and exit 0, OR (b) print a clear error explaining the preset requirement.
3. There is no way to discover `repo-audit`'s sections without running the full audit or already knowing the preset name.

**Required new behavior:**

- `git-context --help` → exit **0**, prints OptionParser help to **stdout**, including the preset list in the banner.
- `git-context -h` → same.
- `git-context` (no args) → exit **1**, prints help to **stderr** (unchanged from v0.2.0).
- `git-context --list-sections` (no preset) → exit **0**, prints to stdout:

  ```
  commit:
    status
    staged_diff
    ...
  repo-audit:
    gitignore_gaps
    tracked_secrets
    missing_standard_files
  ```

- `git-context <preset> --list-sections` → exit **0**, unchanged format (flat list, one token per line).
- `git-context <preset>` normal run → unchanged.

**Implementation sketch:**

- Pre-scan `@argv` for `--help`/`-h` and `--list-sections` BEFORE the preset-required guard runs. If `--help` present, emit parser help on stdout and `exit(0)`. If `--list-sections` present and no preset arg, iterate `PRESETS`, instantiate each, print grouped output, `exit(0)`.
- Update the OptionParser banner to list the available presets so `--help` is actually useful.

**Acceptance criteria:**

- New tests in `test/cli_test.rb`:
  - `test_help_flag_exits_zero_and_prints_to_stdout`
  - `test_short_h_flag_exits_zero`
  - `test_list_sections_without_preset_groups_by_preset`
  - `test_list_sections_without_preset_exits_zero`
  - `test_list_sections_with_preset_still_works` (regression)
  - `test_help_output_lists_available_presets`
- Existing `test_missing_preset_arg_prints_help_and_exits` still asserts exit 1 (no-args case).
- Full suite green.

**TDD cadence:** write all six tests (RED), implement the `--help` / `--list-sections` pre-scan, run suite (GREEN), refactor if the pre-scan logic duplicates OptionParser state.

**Test command:** `bundle exec rake test TEST=test/cli_test.rb` then full suite.

**Return format:** summary + artifact paths + green confirmation.

---

## Task E — Version bump + README/CHANGELOG update

**Model:** Haiku. *Rationale:* file edits with no logic.

**Files touched:**

- Modify: `lib/git_context/version.rb` (`"0.2.0"` → `"0.3.0"`)
- Modify: `README.md` (note new `--help` / grouped `--list-sections` behavior; note `tracked_secrets` tightening)
- Create or Modify: `CHANGELOG.md` (add `## 0.3.0 - 2026-04-17` section enumerating A/B/C/D)

**Depends on:** artifacts produced by Tasks A, B, C, D — all must be committed green before this task starts. Dependency is on the state of `main` after Batches 1+2, not on specific files.

**Acceptance criteria:**

- `GitContext::VERSION == "0.3.0"`.
- `CHANGELOG.md` under `## 0.3.0` lists four bullets: "Fix tracked_secrets false-positive on source files", "Move filesystem access behind Git seam", "Extract shared Preset base class", "Fix --help / --list-sections CLI UX".
- `README.md` CLI examples include `git-context --list-sections` (no preset) showing grouped output, and `git-context --help` noted as exit-0.
- Full suite green (nothing structural should have moved).

**TDD cadence:** n/a (no code changes). Run `bundle exec rake test` as a sanity check.

**Return format:** summary + artifact paths + green confirmation.

---

## Orchestrator checklist

After Batch 1 and Batch 2 subagents all return green:

- [ ] Verify `git status` is clean on `main` (all four tasks have committed their own work).
- [ ] Run `bundle exec rake test` once from the orchestrator side to confirm no merge-order surprise.
- [ ] Dispatch Task E.
- [ ] Final `bundle exec rake test`.
- [ ] Tag `v0.3.0` if the user requests a release (NOT automatic — tagging is a user decision per `CLAUDE.md`'s "only commit when asked" principle extended to tags).

## Self-review notes

- **Issue coverage:** A → Task A. B → Task B. C → Task C. D → Task D. All four issues have a named task with acceptance criteria.
- **Parallelism:** Tasks A, B, C, D touch disjoint files. A touches `tracked_secrets.rb`(+test) and possibly `offenders.rb`. B touches `git.rb`, the other two section files, `test_helper.rb`, `git_test.rb`, and those two section tests. C touches preset files + top-level require. D touches `cli.rb` + its test. Zero overlap.
- **Seam rule:** Task B fully restores the one-seam rule. After B, no section file references `Find`, `Dir.*`, `File.*`, or `git.repo_path`.
- **TDD:** Every task specifies RED-then-GREEN ordering, with the one exception of Task C (pure refactor under existing tests — allowed per `tdd-workflow.md` §"Loop" since coverage already exists).
- **Mocking discipline:** Task B migrates section tests from `TempRepo` to `FakeGit`, correcting a v0.2.0 drift from the standard.
- **No gold-plating:** nothing on this plan beyond the four reported issues plus the integration commit.
