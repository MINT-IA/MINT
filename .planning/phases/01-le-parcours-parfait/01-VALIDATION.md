---
phase: 1
slug: le-parcours-parfait
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-06
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Flutter test + pytest 7.x |
| **Config file** | `apps/mobile/pubspec.yaml` + `services/backend/pytest.ini` |
| **Quick run command** | `cd apps/mobile && flutter test --tags phase1` |
| **Full suite command** | `cd apps/mobile && flutter test && cd ../../services/backend && python3 -m pytest tests/ -q` |
| **Estimated runtime** | ~120 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter test --tags phase1`
- **After every plan wave:** Run full suite (flutter test + pytest)
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 120 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 01-01-01 | 01 | 1 | PATH-05 | — | N/A | unit | `flutter test test/widgets/mint_loading_state_test.dart` | ❌ W0 | ⬜ pending |
| 01-01-02 | 01 | 1 | PATH-05 | — | N/A | unit | `flutter test test/widgets/mint_error_state_test.dart` | ❌ W0 | ⬜ pending |
| 01-02-01 | 02 | 1 | PATH-02 | T-1-01 | Magic link tokens expire after 15min, single-use | unit | `python3 -m pytest tests/test_magic_link.py -q` | ❌ W0 | ⬜ pending |
| 01-02-02 | 02 | 1 | PATH-02 | T-1-01 | Email validation prevents injection | unit | `python3 -m pytest tests/test_magic_link.py::test_email_validation -q` | ❌ W0 | ⬜ pending |
| 01-03-01 | 03 | 2 | PATH-01 | — | N/A | integration | `flutter test test/integration/lea_golden_path_test.dart` | ❌ W0 | ⬜ pending |
| 01-03-02 | 03 | 2 | PATH-03 | — | N/A | unit | `flutter test test/screens/onboarding/quick_start_screen_test.dart` | ❌ W0 | ⬜ pending |
| 01-04-01 | 04 | 2 | PATH-04 | — | N/A | unit | `python3 -m pytest tests/test_coach_firstjob.py -q` | ❌ W0 | ⬜ pending |
| 01-04-02 | 04 | 2 | PATH-04 | — | N/A | unit | `flutter test test/services/regional_voice_service_test.dart` | ✅ | ⬜ pending |
| 01-05-01 | 05 | 3 | PATH-06 | — | N/A | integration | `flutter test integration_test/lea_e2e_test.dart` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/widgets/mint_loading_state_test.dart` — stubs for PATH-05
- [ ] `test/widgets/mint_error_state_test.dart` — stubs for PATH-05
- [ ] `tests/test_magic_link.py` — stubs for PATH-02
- [ ] `test/integration/lea_golden_path_test.dart` — stubs for PATH-01, PATH-06
- [ ] `tests/test_coach_firstjob.py` — stubs for PATH-04

*Existing infrastructure covers framework setup — only test files need creation.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Magic link email delivery | PATH-02 | Requires real email service | Send magic link to test email, verify receipt within 30s |
| Apple Sign-In flow | PATH-02 | Requires iOS device + Apple account | Tap Apple Sign-In on TestFlight build, complete auth |
| VD regional voice perception | PATH-04 | Subjective quality | Read coach response, confirm septante/nonante usage and VD tone |
| 5-minute completion timing | PATH-03 | End-to-end timing | Time full flow from landing to check-in on physical device |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 120s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
