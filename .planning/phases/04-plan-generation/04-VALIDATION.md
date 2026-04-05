---
phase: 04
slug: plan-generation
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-05
---

# Phase 04 — Validation Strategy

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test |
| **Quick run command** | `cd apps/mobile && flutter test test/services/coach/ test/models/ -q` |
| **Full suite command** | `cd apps/mobile && flutter test` |
| **Estimated runtime** | ~120 seconds |

## Sampling Rate

- **After every task commit:** Quick run
- **After every plan wave:** Full suite
- **Max feedback latency:** 120 seconds

## Manual-Only Verifications

| Behavior | Requirement | Why Manual |
|----------|-------------|------------|
| Coach generates plan from "j'veux acheter un appart" | PLN-01 | Requires live LLM |
| Plan card visible on Aujourd'hui tab | PLN-03 | Visual verification |
| Salary change updates plan amount | PLN-04 | End-to-end reactivity |

**Approval:** pending
