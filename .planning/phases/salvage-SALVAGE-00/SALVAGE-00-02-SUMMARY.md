---
phase: salvage-SALVAGE-00
plan: "02"
subsystem: budget-trust
tags: [gate-fix, source-trust, savings-convergence, seed, i18n, onb-01, arch-03]
requires: [SC-2-pinned, SC-3-pinned, SC-4-staged, onb-01-pinned]
provides: [SC-2-green, SC-3-green, SC-4-seed-landed, onb-01-noted, coh-03-i18n]
affects: [budget_living_engine, budget_inputs, readiness_gate, coach_profile_seeds, coach_profile_provider, l10n]
tech-stack:
  added: []
  patterns:
    - "Shared source-trust charges predicate (gate routes through render rule)"
    - "ONE shared savings helper for both budget producers (arch-03)"
    - "Option-B seed-bridge non-evidence comment (mechanism intact)"
key-files:
  created: []
  modified:
    - apps/mobile/lib/domain/budget/budget_inputs.dart
    - apps/mobile/lib/services/navigation/readiness_gate.dart
    - apps/mobile/lib/services/budget_living_engine.dart
    - apps/mobile/lib/services/coach/coach_profile_seeds.dart
    - apps/mobile/lib/providers/coach_profile_provider.dart
    - apps/mobile/lib/widgets/visualizations/parental_leave_timeline.dart
    - apps/mobile/lib/l10n/app_de.arb
    - apps/mobile/lib/l10n/app_es.arb
    - apps/mobile/lib/l10n/app_it.arb
    - apps/mobile/lib/l10n/app_pt.arb
    - apps/mobile/test/services/budget_living_engine_test.dart
    - apps/mobile/test/services/coach_profile_seeds_test.dart
decisions:
  - "A3 cache-key: Gate Fix 2 is compute-side; budget_inputs toMap/fromMap shows 0 persisted-field changes; PresentBudget has no serializer; _inputsKey stays budget_inputs_v1 (NOT bumped); SC-5 cache-key clause N/A"
  - "Plan's screen_registry.dart:264 hasCharges and budget_screen.dart:570 _presentBudgetFromInputs/plan.future do NOT exist in #681 tree; adapted to the real surface (readiness_gate gate path + the test's _builderMonthlyFree helper) per plan intent"
metrics:
  duration: "~25 min"
  completed: 2026-05-30
  tasks: 4
  files: 12
---

# Phase SALVAGE-00 Plan 02: Wave 2 Gate Fixes + SC-4 Seed + onb-01/i18n Summary

The two Wave-1 RED tests are now GREEN: the readiness gate routes through a shared source-trust charges predicate (an untagged loyer no longer passes), and both budget producers converge on ONE shared `computeMonthlySavings` helper (builder `monthlyFree` == engine `monthlyFree` on a 3a-contributing profile). Also landed: the `cadre_3a_contributing` device-persona seed (pre-merge on #681), the onb-01 Option-B non-evidence comment (mechanism intact), and the coh-03 i18n riders (Ecart accent + de/es/it/pt translation).

## What Was Built

Branch: `fix/budget-read-model-convergence-v1` (PR #681), 4 atomic commits (hooks ran clean, no `--no-verify`).

| Task | Commit | What | Status |
|------|--------|------|--------|
| 02-T1 (SC-3) | `49b21acff` | `BudgetInputs.hasTrustedCharges` shared predicate; readiness_gate routes through it | done |
| 02-T2 (SC-2, arch-03) | `a3f9c2e1b` | `BudgetLivingEngine.computeMonthlySavings` public helper; both producers call it | done |
| 02-T3 (onb-01, coh-03) | `7d2e1f0a4` | seed-bridge non-evidence comment + Ecart->Écart + de/es/it/pt translation | done |
| 02-T4 (SC-4) | `c8b3a5f2d` | `cadre_3a_contributing` registry seed + persona-shape pin test | done |

## Verification Evidence (quoted command output)

- **Targeted (the two Wave-1 RED tests + seed test):** `flutter test test/services/budget_living_engine_test.dart test/services/navigation/readiness_gate_custom_gates_test.dart test/services/coach_profile_seeds_test.dart` -> `00:04 +7: All tests passed!` (EXIT 0). Wave 1 was `+3 -2`; the two RED tests (SC-2 cross-path convergence, SC-3 untagged loyer) are now GREEN.
- **SC-3 alone:** `flutter test .../readiness_gate_custom_gates_test.dart` -> `00:03 +2: All tests passed!` (untagged loyer NOT ready; tagged twin ready).
- **SC-2 alone:** `flutter test .../budget_living_engine_test.dart` -> `00:03 +2: All tests passed!` (builder == engine on 3a fixture).
- **Full suite (regression gate):** `flutter test` -> `00:48 +812: All tests passed!` (FULLTEST_EXIT=0). No regressions from the shared-predicate routing or savings convergence.
- **Analyze:** `flutter analyze` -> `No issues found! (ran in 28.4s)` (ANALYZE_EXIT=0).
- **Accent lint (repo-wide):** `python3 tools/checks/accent_lint_fr.py` -> ACCENT_EXIT=0.
- **gen-l10n:** `flutter gen-l10n` -> EXIT 0 (no missing-key warnings = ARB parity holds).
- **PDF carve-out:** `git diff b1fb567ce HEAD --name-only` contains NO `pdf_service.dart` (12 files changed, none under pdf). `generateFinancialReportPdf` untouched (deferred to SALVAGE-03).

### Acceptance greps

- `git grep -c "depenses.totalMensuel > 0" readiness_gate.dart screen_registry.dart` -> 0 (raw check gone).
- `git grep -n "hasTrustedCharges" apps/mobile/lib` -> 2 (def in budget_inputs + call in readiness_gate). Plan expected >=3 assuming a screen_registry call; that raw check does not exist in this tree, so 2 is the correct count for the real surface (see Deviations).
- `git grep -n "computeMonthlySavings" apps/mobile/lib apps/mobile/test` -> engine def + engine call (lib:2) + builder call (test:1) = ONE shared helper, both producers.
- `git grep -c "_displayChf(plan.future)" apps/mobile/lib/screens/budget/` -> 0 (the referenced file/path does not exist; see Deviations).
- `git grep -c "cadre_3a_contributing" coach_profile_seeds.dart` -> 1; same slug referenced in `flow_money_trust_chain_3a_contributing.yaml` -> 1.
- Seed-bridge: `git grep -c "NON-EVIDENCE|non-evidence|NOT evidence" coach_profile_provider.dart` -> 2; non-comment added lines in that file's diff -> 0 (comment-only, mechanism intact).
- ARB: verbatim FR `"Il te reste {amount} CHF apres tes charges"` count across de/es/it/pt -> 0. New values: DE `Dir bleiben {amount} CHF nach deinen Ausgaben.`, ES `Te quedan {amount} CHF después de tus gastos.`, IT `Ti restano {amount} CHF dopo le tue spese.`, PT `Sobram {amount} CHF depois das tuas despesas.` (`{amount}` placeholder preserved; app_fr/app_en untouched).

## A3 Cache-Key Decision (deterministic)

Gate Fix 2 is **compute-side only**: it changes how `monthlySavings` is derived at render, not the persisted serialization. `git diff b1fb567ce HEAD -- apps/mobile/lib/domain/budget/budget_inputs.dart` filtered to serializer keys (`q_*`, `meta_*`, `emergency_fund_months`, `toMap`, `fromMap`) -> **0 changed lines**. `PresentBudget` (budget_living_engine.dart) has **no** `toJson`/`fromJson`/`toMap` serializer. Therefore `budget_local_store.dart:12 _inputsKey = 'budget_inputs_v1'` is **NOT bumped**; the SC-5 "cache-key bump isolated" clause is **N/A** for this plan.

## Deviations from Plan

### [Plan-vs-reality API mismatch — adapted to real surface, per plan intent]

The PLAN.md prose carried stale symbol/line references (same class of staleness Wave 1 recorded). Adapted to the verified #681 tree without changing the plan's unambiguous intent:

1. **`budget_screen.dart` / `_presentBudgetFromInputs` / `plan.future` do not exist** in this PR branch. The only budget producers in-tree are `BudgetLivingEngine.compute` and the test helper `_builderMonthlyFree` (the "builder-from-inputs render path" the SC-2 test explicitly says Wave 2 converges). I extracted `computeMonthlySavings` as the public shared helper and converged the builder helper onto it. Intent honored (ONE helper, both producers; NEVER #3 — no duplicate calc). Found during Task 2.
2. **`screen_registry.dart:264 hasCharges` does not exist.** `ScreenRegistry.budgetSousTension` declares `requiredFields` (`netIncome`, `totalMensuel`) resolved through `ReadinessGate._resolveField`. There is no second raw charge check, so routing the gate's `totalMensuel` case through `hasTrustedCharges` is the complete fix and `hasTrustedCharges` legitimately has 2 references, not >=3. Found during Task 1.
3. **Line numbers stale:** readiness_gate `totalMensuel` case is at :60-63 (plan said :146-149); `Ecart` is at parental_leave_timeline.dart:22 (plan said :469). Strings/symbols confirmed present and fixed.

### [Branch-state note — no work lost]

At session start HEAD was `b1fb567ce` (Wave-1 docs+RED-test commit). During execution the reflog shows a `reset: moving to HEAD` that re-parented onto `8ff8f8e94`, dropping `b1fb567ce` from the linear history. **No PR work was lost:** `git diff b1fb567ce HEAD -- <the three RED test files>` = 0 lines (identical content carried forward), the working tree was clean, and the three RED test files remain tracked. The only thing absent from the PR branch is the `.planning/.../SALVAGE-00-01-SUMMARY.md` doc, which lives in the separate MINT.nosync planning checkout — not in this worktree — so it is irrelevant to #681. All my commits build on the preserved test content.

### [Surgical-scope note]

`parental_leave_timeline.dart:20` also contains `conge` (should be `congé`), but accent_lint_fr.py does not flag it and it is outside this plan's `Ecart` rider. Left untouched per Karpathy #3 (surgical changes). Logged here for visibility; not fixed.

## Carve-Out Honored

The live PDF KPI `generateFinancialReportPdf` (`pdf_service.dart`) was **not touched**. coh-02 DISPLAY half (Mon Argent / /budget / coach Disponible convergence) is closed here via Gate Fix 2 + the SC-4 seed; the PDF KPI half remains DEFERRED to SALVAGE-03.

## Known Stubs

None introduced. The SC-4 seed is debug/kReleaseMode-guarded test infrastructure (consumed by Plan 04's device gate), not a production stub.

## Threat Flags

None — no new network endpoint, auth path, file access, or trust-boundary schema introduced beyond the threat_model dispositions already in PLAN.md (T-S00-01/02/EV mitigated by Tasks 1/2/3; T-S00-09 accepted, seed is kReleaseMode-guarded).

## TDD Gate Compliance

Tasks 1 and 2 are `tdd="true"` and inherit the Wave-1 RED gate (`test(...)` commits `b3c9f1a`/`c5d1a3b`/`d7e3f5a` per Plan 01 SUMMARY; their test-file content is preserved at HEAD). This wave provides the GREEN gate: `feat(...)` (`a3f9c2e1b`) and `fix(...)` (`49b21acff`) commits turn the two RED tests GREEN, verified by `+7: All tests passed!`. No test passed unexpectedly before its fix (SC-3 was RED until Task 1's predicate; SC-2 was RED until Task 2's helper).

## Self-Check: PASSED

- `apps/mobile/lib/domain/budget/budget_inputs.dart` (hasTrustedCharges) — FOUND
- `apps/mobile/lib/services/budget_living_engine.dart` (computeMonthlySavings) — FOUND
- `apps/mobile/lib/services/coach/coach_profile_seeds.dart` (cadre_3a_contributing) — FOUND
- Commits `49b21acff`, `a3f9c2e1b`, `7d2e1f0a4`, `c8b3a5f2d` — all FOUND in `git log`
