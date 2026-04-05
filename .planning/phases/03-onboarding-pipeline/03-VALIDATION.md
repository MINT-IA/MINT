---
phase: 03
slug: onboarding-pipeline
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-05
---

# Phase 03 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (Flutter SDK) |
| **Config file** | apps/mobile/pubspec.yaml |
| **Quick run command** | `cd apps/mobile && flutter test test/services/coach/ test/screens/onboarding/ -q` |
| **Full suite command** | `cd apps/mobile && flutter test` |
| **Estimated runtime** | ~120 seconds |

---

## Sampling Rate

- **After every task commit:** Run quick command
- **After every plan wave:** Run full suite
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 120 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 03-01-01 | 01 | 1 | ONB-03 | unit | `flutter test test/services/coach/intent_router_test.dart` | ❌ W0 | ⬜ pending |
| 03-01-02 | 01 | 1 | ONB-01 | unit | `flutter test test/services/chiffre_choc_selector_test.dart` | ✅ | ⬜ pending |
| 03-02-01 | 02 | 2 | ONB-02 | unit | `flutter test test/screens/onboarding/intent_screen_test.dart` | ✅ | ⬜ pending |
| 03-02-02 | 02 | 2 | ONB-04 | widget | `flutter test test/screens/main_tabs/mint_home_screen_test.dart` | ✅ | ⬜ pending |

---

## Wave 0 Requirements

- [ ] `test/services/coach/intent_router_test.dart` — stubs for ONB-03 (IntentRouter mapping)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Premier eclairage appears within 3 minutes of cold launch | ONB-01 | Timing + visual | Cold launch, select intent chip, time to first number display |
| Post-onboarding home differs by intent | ONB-04 | Visual comparison | Select different intents, compare home screens |

---

## Validation Sign-Off

- [ ] All tasks have automated verify or Wave 0 dependencies
- [ ] Sampling continuity maintained
- [ ] Wave 0 covers all MISSING references
- [ ] Feedback latency < 120s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
