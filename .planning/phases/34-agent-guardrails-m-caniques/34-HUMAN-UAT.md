---
status: partial
phase: 34-agent-guardrails-m-caniques
source: [34-VERIFICATION.md]
started: 2026-04-22T21:40:00Z
updated: 2026-04-22T21:40:00Z
verify_type: observation_window
---

## Current Test

[awaiting real-world observation — calendar-gated and traffic-gated]

## Tests

### 1. lefthook-ci.yml runs green on first real PR

expected: First PR opened from `feature/S30.7-tools-deterministes` (or future feature branches) to `dev` triggers `.github/workflows/lefthook-ci.yml`, the job installs lefthook + runs `lefthook run pre-commit --all-files --force` on the PR diff range, and completes with exit 0. This is the D-24 **primary** bypass ground-truth — catches anyone who silently used `--no-verify`.
result: [pending — requires opening a PR]

### 2. bypass-audit.yml weekly cron fires Monday 09:00 UTC

expected: On the first Monday post-merge, `.github/workflows/bypass-audit.yml` fires via cron schedule `0 9 * * 1`. Workflow scans `git log --since="7 days ago" dev` for `LEFTHOOK_BYPASS` or `[bypass:` markers. If zero markers and zero `--no-verify` silent bypasses, it exits cleanly with no issue created. Manual validation: visit Actions tab Monday AM, confirm green run.
result: [pending — calendar-gated]

### 3. Synthetic bypass detection creates/updates GitHub issue at threshold

expected: When >3 `LEFTHOOK_BYPASS=1` commits land on `dev` within 7 days, `bypass-audit.yml` opens (or updates) a GitHub issue labelled `bypass-audit` listing each commit hash + author + subject + body excerpt. Requires deliberate hostile-scenario test: push 4 test commits with `LEFTHOOK_BYPASS=1 git commit --allow-empty -m "bypass test N [bypass: deliberate UAT]"`, wait for workflow_dispatch or next cron, verify issue appears.
result: [pending — requires deliberate hostile-scenario test post-merge]

### 4. CI time reduction measured against claim

expected: After 5+ PRs land on `dev` post-merge, rolling median of `.github/workflows/ci.yml` duration reduces by the RESEARCH-estimated 15-90 seconds per PR (not the ROADMAP's ~2 min — RESEARCH reconciled the actual delta). Compare via `gh run list --workflow=ci.yml --json conclusion,startedAt,updatedAt` pre/post merge window. Document the measured delta; if negative (CI slower), investigate.
result: [pending — requires 5+ post-merge PRs to measure rolling median]

## Summary

total: 4
passed: 0
issues: 0
pending: 4
skipped: 0
blocked: 0

## Gaps

None. All 4 items are explicitly `verify_type: observation_window` per Plan 34-07 design — they cannot be validated inside a PR merge window by design (require cron firings, real PR traffic, or rolling-median aggregate). The Phase 34 code-side gate is 10/10 PASS per VERIFICATION.md. These are operational validations deferred to post-merge window. Non-blocking for `/gsd-verify-work 34` sign-off per autonomous profile L1 (ADR-20260419-autonomous-profile-tiered) — mirrors Phase 30.7 J0 smoke deferral pattern.
