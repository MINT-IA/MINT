---
phase: 1
slug: le-parcours-parfait
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-04-06
updated: 2026-04-06
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Flutter test + pytest 8.x |
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
| 01-01-01 | 01 | 1 | PATH-05 | — | N/A | unit | `flutter test test/widgets/state_widgets_test.dart` | Created by Plan 01-01 Task 1 | pending |
| 01-02-01 | 02 | 1 | PATH-02 | T-1-02 | Magic link tokens expire after 15min, single-use | unit | `python3 -m pytest tests/test_magic_link.py -q` | Created by Plan 01-02 Task 1 | pending |
| 01-02-02 | 02 | 1 | PATH-02 | T-1-04 | Email validation prevents injection | unit | `python3 -m pytest tests/test_magic_link.py::test_email_validation -q` | Created by Plan 01-02 Task 1 | pending |
| 01-03-01 | 03 | 2 | PATH-01 | — | N/A | integration | `flutter analyze lib/screens/onboarding/` | Verified by Plan 01-03 Task 1 | pending |
| 01-03-02 | 03 | 2 | PATH-03 | — | N/A | unit | `flutter analyze lib/screens/onboarding/quick_start_screen.dart` | Verified by Plan 01-03 Task 1 | pending |
| 01-03-03 | 03 | 2 | PATH-04 | — | N/A | unit | `python3 -m pytest tests/test_coach_firstjob.py -q` | Created by Plan 01-03 Task 2 | pending |
| 01-04-01 | 04 | 3 | PATH-06 | — | N/A | integration | `flutter test test/journeys/lea_golden_path_test.dart` | Created by Plan 01-04 Task 1 | pending |
| 01-04-02 | 04 | 3 | PATH-04 | — | N/A | unit | `flutter test test/services/regional_voice_service_test.dart` | Exists | pending |
| 01-05-01 | 05 | 2 | PATH-02 | T-1-11 | Apple identity token verified server-side | unit | `flutter test test/services/apple_sign_in_service_test.dart` | Created by Plan 01-05 Task 1 | pending |

*Status: pending | green | red | flaky*

---

## Wave 0 Requirements

All test files are created by their respective plan tasks (no separate Wave 0 needed):

- [x] `test/widgets/state_widgets_test.dart` — created by Plan 01-01 Task 1 (PATH-05)
- [x] `tests/test_magic_link.py` — created by Plan 01-02 Task 1 (PATH-02)
- [x] `tests/test_coach_firstjob.py` — created by Plan 01-03 Task 2 (PATH-04)
- [x] `test/journeys/lea_golden_path_test.dart` — created by Plan 01-04 Task 1 (PATH-01, PATH-06)
- [x] `test/services/apple_sign_in_service_test.dart` — created by Plan 01-05 Task 1 (PATH-02)

*All test files are created within their plan tasks using TDD (tdd="true") — tests written before implementation.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Magic link email delivery | PATH-02 | Requires real email service | Send magic link to test email, verify receipt within 30s |
| Apple Sign-In flow | PATH-02 | Requires iOS device + Apple account | Tap Apple Sign-In on TestFlight build, complete auth (Plan 01-05 checkpoint) |
| VD regional voice perception | PATH-04 | Subjective quality | Read coach response, confirm septante/nonante usage and VD tone |
| 5-minute completion timing | PATH-03 | End-to-end timing | Time full flow from landing to check-in on physical device |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify commands
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] All test files created by plan tasks (no orphan Wave 0 references)
- [x] No watch-mode flags
- [x] Feedback latency < 120s
- [x] Test file paths match plan outputs exactly
- [x] No `2>/dev/null` in any verify command
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
