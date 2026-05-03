# Changelog

All notable changes to this kit are documented here. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), versioning follows [SemVer](https://semver.org/).

## [0.1.0] — 2026-05-03

### Added
- Initial kit structure (additive-only, no overwrites)
- 13 disciplines documented in `docs/DISCIPLINES.md` (7 engineering + 6 context engineering)
- `docs/ANTI_PATTERNS.md` table of common AI-coding failures
- `docs/CLAUDE_RUNTIME.md` Claude-version-specific notes (Claude Opus 4.7, May 2026)
- `docs/CUSTOMIZATION.md` how to add project-specific rules without losing them on upgrade
- `bin/bootstrap.sh` — additive installer with `--dry-run` (default), `--apply`, `--lang` flags
- `bin/doctor.sh` — diagnose project's discipline state (lints registered, hooks wired, evidence pattern)
- `bin/uninstall.sh` — clean removal via lock file
- `skills/claude-code-discipline/SKILL.md` — manual-trigger Claude Code skill
- `templates/CLAUDE.md.en.template` with marker blocks for project-specific overrides
- `templates/lefthook.discipline.yml` — overlay never overwrites existing `lefthook.yml`
- `templates/.gitattributes.template` — discipline marker block protection
- `lints/lint_status_audit.py` — pure stdlib Python 3.10+, no deps
- `lints/tests/test_lint_status_audit.py` — pytest fixtures
- `tests/bats/test_bootstrap.bats` — bats-core integration tests for bootstrap
- `LICENSE` MIT
- `PRIVACY.md` zero-telemetry statement

### Composes with
- `obra/superpowers` (kit detects and defers disciplines 1-7 if installed)
- `muratcankoylan/Agent-Skills-for-Context-Engineering` (no overlap by design)
- `gstack` (kit voice-trigger frontmatter compatible)
- GSD framework (kit maps R/P/I to gsd-discuss-phase/gsd-plan-phase/gsd-execute-phase if detected)

### Known limitations (V1)
- Single-package layout (3-package split scheduled V0.2)
- EN-only template (FR scheduled V0.4)
- No `upgrade.sh` yet (manual re-run of `bootstrap.sh --apply` works but doesn't preserve customizations cleanly)
- No CI workflow template yet (`.github/workflows/discipline-gates.yml` scheduled V0.2)
- macOS bash 3.2 + Linux bash 5.x tested; Windows = WSL only
