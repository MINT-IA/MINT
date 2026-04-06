---
phase: 6
slug: calculator-wiring
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-06
---

# Phase 6 — Validation Strategy

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
| 06-01-01 | 01 | 1 | CAL-01 | — | N/A | widget | `flutter test test/screens/calculator_prefill_test.dart` | ❌ W0 | ⬜ pending |
| 06-01-02 | 01 | 1 | CAL-02 | — | N/A | unit | `flutter test test/services/route_planner_test.dart` | ❌ W0 | ⬜ pending |
| 06-02-01 | 02 | 2 | CAL-03 | — | N/A | unit | `flutter test test/services/calculator_writeback_test.dart` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/screens/calculator_prefill_test.dart` — stubs for CAL-01 prefill verification
- [ ] `test/services/route_planner_test.dart` — stubs for CAL-02 GoRouter extras
- [ ] `test/services/calculator_writeback_test.dart` — stubs for CAL-03 write-back

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Golden couple prefill matches expected values | CAL-01 | Requires CoachProfile with Julien's exact data | Set up profile with Julien's data, navigate to /rente-vs-capital, verify 70,377 CHF shown |
| Write-back triggers plan staleness | CAL-03 | Requires FinancialPlanProvider state observation | Run simulation, verify FinancialPlanProvider.isPlanStale changes |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 120s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
