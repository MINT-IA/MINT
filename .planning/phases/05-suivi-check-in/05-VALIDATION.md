---
phase: 5
slug: suivi-check-in
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-05
---

# Phase 5 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Flutter test + pytest |
| **Config file** | `apps/mobile/pubspec.yaml` + `services/backend/pytest.ini` |
| **Quick run command** | `cd apps/mobile && flutter test test/services/` |
| **Full suite command** | `cd apps/mobile && flutter test && cd ../../services/backend && python3 -m pytest tests/ -q` |
| **Estimated runtime** | ~120 seconds |

---

## Sampling Rate

- **After every task commit:** Run `cd apps/mobile && flutter test test/services/`
- **After every plan wave:** Run full suite command
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 120 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 05-01-01 | 01 | 1 | SUI-01 | — | N/A | unit | `flutter test test/services/check_in_notification_test.dart` | ❌ W0 | ⬜ pending |
| 05-01-02 | 01 | 1 | SUI-02 | — | N/A | unit | `flutter test test/services/check_in_tool_test.dart` | ❌ W0 | ⬜ pending |
| 05-02-01 | 02 | 2 | SUI-03 | — | N/A | widget | `flutter test test/widgets/plan_reality_card_test.dart` | ❌ W0 | ⬜ pending |
| 05-02-02 | 02 | 2 | SUI-04 | — | N/A | unit | `flutter test test/services/conversation_memory_test.dart` | ❌ W0 | ⬜ pending |
| 05-02-03 | 02 | 2 | SUI-05 | — | N/A | widget | `flutter test test/widgets/streak_badge_test.dart` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/services/check_in_notification_test.dart` — stubs for SUI-01
- [ ] `test/services/check_in_tool_test.dart` — stubs for SUI-02
- [ ] `test/widgets/plan_reality_card_test.dart` — stubs for SUI-03
- [ ] `test/services/conversation_memory_test.dart` — stubs for SUI-04
- [ ] `test/widgets/streak_badge_test.dart` — stubs for SUI-05

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Notification appears on device | SUI-01 | Local notifications require device/emulator | Open app, advance date to 1st of month, verify notification fires |
| Coach conversation flow feels natural | SUI-02 | Subjective UX quality | Send check-in, verify coach asks sequential questions, summarizes |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 120s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
