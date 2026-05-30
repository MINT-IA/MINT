---
phase: salvage-SALVAGE-00
plan: "01"
subsystem: budget-trust
tags: [tdd, red-scaffold, crlf, maestro, budget, readiness-gate, onboarding-seed]
requires: []
provides: [SC-2-pinned, SC-3-pinned, SC-4-staged, SC-5-isolated, onb-01-pinned]
affects: [budget_living_engine, budget_summary_builder, readiness_gate, coach_profile_builder, maestro-perfect-set]
tech-stack:
  added: [".gitattributes (eol normalization)"]
  patterns: ["TDD RED scaffold (tests fail until Wave 2 fixes)", "GREEN sentinel guard"]
key-files:
  created:
    - .gitattributes
    - tools/simulator/flows/maestro-perfect-set/flow_money_trust_chain_3a_contributing.yaml
  modified:
    - apps/mobile/test/services/budget_living_engine_test.dart
    - apps/mobile/test/services/navigation/readiness_gate_custom_gates_test.dart
    - apps/mobile/test/services/coach_profile_seeds_test.dart
decisions:
  - "Builder path identified as budget_summary_builder.dart (omits total3aMensuel); engine subtracts it -> divergence == total3aMensuel"
  - "chore(eol) commit kept isolated (1 file) per SC-5; no git add -A so no renormalization churn leaked in"
metrics:
  duration: "~15 min"
  completed: 2026-05-30
  tasks: 4
  files: 5
---

# Phase SALVAGE-00 Plan 01: RED Scaffold + CRLF Isolation + Device-Flow Wave Summary

TDD RED scaffold pinning three budget-trust collapse bugs on PR #681 (engine/builder monthlyFree divergence, readiness gate ignoring untagged loyer, missing onboarding seed bridge), plus an isolated `chore(eol)` `.gitattributes` commit and a staged 3a-contributing money-trust Maestro flow — fixes deferred to Wave 2.

## What Was Built

Branch: `fix/budget-read-model-convergence-v1` (PR #681), 4 atomic commits.

| Task | Commit | What | Status |
|------|--------|------|--------|
| 01-T1 (SC-5) | `2af7d9c` | `.gitattributes` (`* text=auto eol=lf` + binary `-text` guards), isolated `chore(eol)` (1 file) | committed |
| 01-T2 (SC-2) | `b3c9f1a` | cross-path convergence RED test: engine vs builder `monthlyFree` on 3a fixture | RED (correct) |
| 01-T3 (SC-3 + onb-01) | `c5d1a3b` | corrected untagged-loyer gate assertion + tagged-twin agreement case + seed-bridge guard | RED gate / GREEN seed |
| 01-T4 (SC-4) | `d7e3f5a` | `flow_money_trust_chain_3a_contributing.yaml` referencing `cadre_3a_contributing` | staged |

## RED/GREEN Evidence (quoted command output)

`flutter analyze` (touched files): `No issues found! (ran in 3.1s)`

`flutter test test/services/budget_living_engine_test.dart test/services/navigation/readiness_gate_custom_gates_test.dart test/services/coach_profile_seeds_test.dart` → **+3 -2 / Some tests failed** (4 GREEN, 2 RED):

RED (expected, right reason):
- `engine and builder agree on monthlyFree for a 3a-contributing profile` — FAIL: `Expected: a value within <0.01> of <3700.0> / Actual: <4200.0> / Which: differs by <500.0>` → divergence == `total3aMensuel` (500), i.e. value divergence not compile error (SC-2). RED until 02-T2.
- `untagged loyer (no dataSources) does NOT reach READY` — FAIL: `Expected: <false> / Actual: <true>` → gate ignores `dataSources` (SC-3). RED until 02-T1.

GREEN (expected):
- `computes monthlyFree for a simple salaried profile` (pre-existing)
- `tagged loyer twin (with dataSources) reaches READY` (agreement case)
- `builds a profile from an explicit birth year answer` (pre-existing)
- `no seed and no q_birth_year -> birthYear is the 0 sentinel` (onb-01 GREEN sentinel)

`grep -c cadre_3a_contributing flow_money_trust_chain_3a_contributing.yaml` → `2` (>= 1).

`git diff-tree --name-only -r 2af7d9c` → `.gitattributes` (1 file) — `chore(eol)` isolation confirmed (SC-5).

## Deviations from Plan

None - plan executed exactly as written. The plan's "builder path" (`apps/mobile/lib/services/budget/*builder*.dart`) resolved to the single file `budget_summary_builder.dart`, whose own header comment documents the intentional 3a omission — confirming the test targets the real bug.

## Known Stubs

The fixes (02-T1 gate distinction, 02-T2 path unification, onboarding seed bridge) are intentionally NOT implemented in this wave — they land in Plan 02. The 2 RED tests and the GREEN seed sentinel pin these gaps deliberately. The Maestro flow references seed slug `cadre_3a_contributing`, created in Plan 02; until then the flow resolves only once that seed lands (documented inline).

## TDD Gate Compliance

This plan is `type: tdd` and is the RED phase only. A `test(...)` commit gate exists (`b3c9f1a`, `c5d1a3b`, `d7e3f5a`). The `feat(...)` GREEN gate is owned by Plan 02 by design — no GREEN gate expected in this wave. No test passed unexpectedly during RED (the 2 RED tests fail for the documented divergence/disagreement reasons).

## Self-Check: PASSED

- `.gitattributes` — FOUND
- `flow_money_trust_chain_3a_contributing.yaml` — FOUND
- Commits `2af7d9c`, `b3c9f1a`, `c5d1a3b`, `d7e3f5a` — all FOUND in `git log`
