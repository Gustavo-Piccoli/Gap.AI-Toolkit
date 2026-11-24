# Changelog

All notable changes to this project are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Changed
- Installation docs create a virtual environment in `mcp/review-hub/.venv`, and `Setup-Environment.ps1` prefers its Python for `review-hub`, warning when the selected interpreter lacks the `mcp` package.
- README documents that `Setup-Environment.ps1` rewrites `~/.claude/CLAUDE.md`, so existing instructions belong in an overlay.
- `Setup-Environment.ps1` no longer touches legacy `gustavo-*` skills by default; pass `-RemoveLegacyGustavoSkills $true` to retire them.

### Fixed
- `Setup-Environment.ps1` registers `review-hub` in the root `mcpServers` of `~/.claude.json`; it used to insert it into the first project-scoped `mcpServers`, making the server available in a single folder only.
- `Setup-Environment.ps1` registers `review-hub` when `~/.gemini/config/mcp_config.json` exists but is empty.
- `Setup-Environment.ps1` moves legacy `gustavo-*` skill folders to `skills-legacy-backup/<timestamp>` instead of deleting them permanently.

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

[Unreleased]: https://github.com/Gustavo-Piccoli/Gap.AI-Toolkit/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/Gustavo-Piccoli/Gap.AI-Toolkit/releases/tag/v0.1.0
