# Changelog

All notable changes to this project are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses [Semantic Versioning](https://semver.org/).

## [0.1.0] - 2026-11-24

First public-ready release.

### Added
- Universal agent rules (`rules/AGENTS.md`) and 12 `gap-*` skills for Claude Code and Google Antigravity.
- `review-hub` MCP server (FastMCP) for multi-agent code review threads.
- Windows bootstrap (`Setup-Environment.ps1`), workspace linking (`Link-WorkspaceAgents.ps1`) and configuration templates in `adapters/`.
- `review-hub`: `pyproject.toml`, `review-hub` console script and a pytest suite (creation, listing, replies, corrupted files, concurrent threads and processes, MCP round trip).
- `REVIEW_HUB_STORAGE` environment variable to choose the thread file.
- CI on GitHub Actions: ruff and pytest (Ubuntu and Windows), PSScriptAnalyzer, the repository scanner with example patterns and gitleaks.
- Storage format docs with a JSON Schema, and a fictional end-to-end example in `examples/`.
- MIT license.

### Changed
- `review-hub` allocates ids with `max(id) + 1`, writes atomically under a cross-process file lock and stores UTC timestamps.
- `Test-SensitiveData.ps1` reads organization-specific patterns from a local file outside the repository, never prints matched values and detects literals split by string concatenation.
- The `pre-commit` hook checks the author e-mail against the local patterns and works with `pwsh` or `powershell.exe`.

### Fixed
- `review-hub` no longer resets the thread silently when the JSON file is corrupted; it raises an error and leaves the file untouched.
- `mcp` is pinned to `1.30.0`: the previous `mcp>=1.0.0` installed 2.x, where `FastMCP` was renamed, breaking fresh installs.

[0.1.0]: https://github.com/Gustavo-Piccoli/Gap.AI-Toolkit/releases/tag/v0.1.0
