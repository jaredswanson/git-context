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
