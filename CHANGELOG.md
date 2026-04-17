# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.4.0] - 2026-04-17

### Added
- Add `repo-init` command with curated gitignore patterns, LICENSE heuristic, and remote-creation proposals
- Add `commit-apply` command for applying pre-generated commit messages to staged changes
- Add `--json` structured output for new commands (shape: `{ command, version, exit_code, actions_taken, proposals, context, warnings }`)
- Introduce `GitContext::Workspace` seam for filesystem writes and external CLIs (`gh`, `tea`)
- Add `StackDetector` for detecting stacks: ruby_gem, node, python, claude_plugin, generic
- Add `JsonReport` collector/serializer for structured JSON output

## [0.3.0] - 2026-04-17

- Fix tracked_secrets false-positive on source files
- Move filesystem access behind Git seam
- Extract shared Preset base class
- Fix --help / --list-sections CLI UX
