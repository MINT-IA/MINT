---
phase: 1
slug: pre-refactor-cleanup
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-05
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Flutter test (built-in SDK ^3.6.0) |
| **Config file** | `apps/mobile/pubspec.yaml` |
| **Quick run command** | `cd apps/mobile && flutter analyze --no-pub` |
| **Full suite command** | `cd apps/mobile && flutter analyze --no-pub && flutter test --no-pub -q` |
| **Estimated runtime** | ~65 seconds (4s analyze + 60s test) |

---

## Sampling Rate

- **After every task commit:** Run `cd apps/mobile && flutter analyze --no-pub`
- **After every plan wave:** Run `cd apps/mobile && flutter analyze --no-pub && flutter test --no-pub -q`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 65 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 01-01-01 | 01 | 1 | CLN-01 | — | N/A | compile | `cd apps/mobile && flutter analyze --no-pub` | ✅ | ⬜ pending |
| 01-02-01 | 02 | 1 | CLN-02 | — | N/A | compile | `cd apps/mobile && flutter analyze --no-pub` | ✅ | ⬜ pending |
| 01-03-01 | 03 | 1 | CLN-03 | — | N/A | compile+unit | `cd apps/mobile && flutter analyze --no-pub && flutter test --no-pub -q` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements. No new test framework or fixtures needed.

The only test modification is removing `AskMintScreen` assertions from `core_app_screens_smoke_test.dart` when that screen is deleted (part of Task 01-03-01, not Wave 0).

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Route table completeness | CLN-02 | No automated route-coverage test exists | Enumerate GoRoute entries in app.dart, verify each is live/redirected/archived |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 65s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
