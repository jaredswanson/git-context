# git-context

Gathers the git state you'd normally eyeball before writing a commit message — status, staged/unstaged diffs, recent log, per-file history, and untracked file contents — and assembles it into one structured report. Useful as context for an AI commit-message writer, or just for a quick human overview.

## Install

Add to your Gemfile:

```ruby
gem "git-context"
```

Or install directly:

```
gem install git-context
```

## CLI

```
git_context [repo_path]
```

`repo_path` defaults to the current directory. Output is written to stdout.

## Library

```ruby
require "git_context"

git = GitContext::Git.new("/path/to/repo")
puts GitContext::Report.new(git: git).to_s
```

`Report` accepts a custom `sections:` array — each section is any object responding to `#title` and `#render(git)`. Built-in sections live under `GitContext::Sections` (`Status`, `StagedDiff`, `UnstagedDiff`, `RecentLog`, `FileHistory`, `UntrackedFiles`).

## Development

```
bundle install
bundle exec rake test
```
