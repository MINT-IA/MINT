---
phase: 14
slug: commitment-devices
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-12
---

# Phase 14 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | pytest 7.x (backend) + flutter test (mobile) |
| **Config file** | `services/backend/pytest.ini` / `apps/mobile/pubspec.yaml` |
| **Quick run command** | `cd services/backend && python3 -m pytest tests/ -q --tb=short` / `cd apps/mobile && flutter test --no-pub` |
| **Full suite command** | `cd services/backend && python3 -m pytest tests/ -q` && `cd apps/mobile && flutter test` |
| **Estimated runtime** | ~120 seconds |

---

## Sampling Rate

- **After every task commit:** Run quick test command for modified layer
- **After every plan wave:** Run full suite for both layers
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 120 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 14-01-01 | 01 | 1 | CMIT-01, CMIT-05, CMIT-06 | unit | `pytest tests/test_commitment_devices.py -q` | ❌ W0 | ⬜ pending |
| 14-02-01 | 02 | 2 | CMIT-01, CMIT-02 | widget | `flutter test test/widgets/commitment_card_test.dart --no-pub` | ❌ W0 | ⬜ pending |
| 14-02-02 | 02 | 2 | CMIT-02 | unit | `flutter test test/services/notification_commitment_test.dart --no-pub` | ❌ W0 | ⬜ pending |
| 14-03-01 | 03 | 3 | CMIT-03, CMIT-04 | unit | `pytest tests/test_fresh_start.py -q` | ❌ W0 | ⬜ pending |
| 14-03-02 | 03 | 3 | CMIT-03, CMIT-04 | unit | `flutter test test/services/fresh_start_test.dart --no-pub` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `services/backend/tests/test_commitment_devices.py` — stubs for CMIT-01, CMIT-05, CMIT-06
- [ ] `services/backend/tests/test_fresh_start.py` — stubs for CMIT-03, CMIT-04
- [ ] `apps/mobile/test/widgets/commitment_card_test.dart` — stubs for CMIT-01, CMIT-02
- [ ] `apps/mobile/test/services/notification_commitment_test.dart` — stubs for CMIT-02
- [ ] `apps/mobile/test/services/fresh_start_test.dart` — stubs for CMIT-03, CMIT-04

*Existing test infrastructure covers framework installation.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| CommitmentCard UX quality | CMIT-01 | Conversational feel assessment | Send financial question, verify intention card appears, test edit/accept/dismiss |
| Local notification fires at scheduled time | CMIT-02 | Real device notification system | Accept commitment, set reminder 1 min ahead, verify notification fires |
| Fresh-start notification on landmark date | CMIT-03, CMIT-04 | Date-dependent real notification | Set device date to birthday, verify notification with personalized message |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 120s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
