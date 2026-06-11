---
phase: mint-illogism-fixes
plan: 10
subsystem: ui
tags: [rente-vs-capital, fiction-defaults, profile-data-source, empty-state, illog-01, matrix-d5, i18n, maestro, arbitrage]

# Dependency graph
requires:
  - phase: mint-illogism-fixes-09
    provides: RenteVsCapitalScreen Semantics screen-root boundary (AX tree GREEN) — mechanically unblocks the ILLOG-01 Maestro gate
provides:
  - RenteVsCapitalScreen sourcing only from ProfileDataSource (no hardcoded fiction defaults)
  - "_hasUsableInputs guard: no engine projection on a phantom (invented) LPP avoir"
  - Explicit localized empty-state invitation (renteVsCapitalEmptyState ×6 ARB)
  - bug__ILLOG01__rvc_fiction_defaults.yaml GREEN (was OPEN-RED) — closes MATRIX D5 + ILLOG-01
  - rente_vs_capital_defaults_test.dart (permanent regression: empty-state + hasEstimates prefill)
affects: [rente-vs-capital, profile-data-source, maestro-gates, matrix-d5]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Inputs sourced exclusively from _autoFillFromProfile (ProfileDataSource-tagged) — controllers start EMPTY, never pre-invented; the only allowed states are an explicit empty state OR a profile-derived value tagged estimé"
    - "Compute-guard (_hasUsableInputs): the engine is never called on a phantom avoir; with no usable LPP input the result is cleared so the empty state renders instead of a fictional projection"
    - "Empty-state hint uses Semantics(label:) + inner ExcludeSemantics Text (no AX label doubling) — same discrete-node pattern plan 09 established for fields"

key-files:
  created:
    - apps/mobile/test/screens/rente_vs_capital_defaults_test.dart
  modified:
    - apps/mobile/lib/screens/arbitrage/rente_vs_capital_screen.dart
    - apps/mobile/lib/l10n/app_fr.arb
    - apps/mobile/lib/l10n/app_en.arb
    - apps/mobile/lib/l10n/app_de.arb
    - apps/mobile/lib/l10n/app_es.arb
    - apps/mobile/lib/l10n/app_it.arb
    - apps/mobile/lib/l10n/app_pt.arb
    - apps/mobile/test/screens/arbitrage_screens_smoke_test.dart
    - tools/simulator/flows/regression/_INDEX.md
    - .planning/phases/mint-illogism-fixes/mint-illogism-fixes-VALIDATION.md

key-decisions:
  - "Controllers start EMPTY rather than seeded with a sentinel: empty is the honest representation of 'unknown — ask the user'. The ONLY fill path is _autoFillFromProfile (ProfileDataSource), so any prefilled value is provenance-tracked (hasEstimates) and never confusable with fiction."
  - "Added a compute-guard (_hasUsableInputs) instead of only zeroing the engine fallbacks: zeroing the parse fallbacks alone would still feed 0-valued inputs to the engine and could render a degenerate '0 CHF' projection. The guard clears the result entirely, so the user sees the empty-state CTA — not a meaningless projection — when no usable LPP exists. This is what closes D5 (independent sans LPP no longer gets ~812'886 on a ghost balance)."
  - "Conversion-rate defaults (6.8 / 5.0) kept as legitimate survivors: they are the Swiss LPP statutory minima (regulatory constants), NOT user-data fiction. They are clearly editable percent fields and do not, on their own, produce a projection (a projection requires a usable capital, which is gated). Each survivor is justified per the Task 1 acceptance criteria."
  - "Two smoke tests that ENCODED the old bug were updated (Rule 1): 'has default LPP total input pre-filled' asserted '350' was pre-filled (the fiction) and now asserts the empty state; 'renders reachable semantic disclaimer and legal sources' relied on a result that only existed because of the fiction default, so it now seeds a profile with a real LPP."

# Metrics
metrics:
  duration: ~55 min
  completed: 2026-06-11
  tasks: 2
  commits: 3
  files_created: 1
  files_modified: 16
---

# Phase mint-illogism-fixes Plan 10: W3 / ILLOG-01 RenteVsCapital Fiction Defaults Summary

**One-liner:** Killed the RenteVsCapitalScreen fiction defaults (age '50' / salaire '100000' / LPP '350000' + certificate 500000/150000/37000) that bypassed ProfileDataSource and rendered a phantom « Capital estimé à 65 ans ~812'886 » on a ghost LPP — controllers now start empty and source only from `_autoFillFromProfile`, a `_hasUsableInputs` guard prevents any projection on a phantom avoir, and an explicit localized empty state invites the user to complete their profile; `bug__ILLOG01__rvc_fiction_defaults.yaml` flips OPEN-RED → GREEN (cold + warm on iPhone 16e), closing MATRIX D5.

## What Was Built

### Task 1 — Remove fiction defaults (TDD RED → GREEN) — commits `4068ba429` + `45963a677`

- **RED (`4068ba429`)** — `apps/mobile/test/screens/rente_vs_capital_defaults_test.dart` (4 cases) pins both allowed states: (1) no usable profile → input fields EMPTY (no '50' / '100000' / '350000', certificate 500000/150000/37000 removed) + an explicit `renteVsCapitalEmptyState` invitation rendered; (2) a profile with a real *estimated* LPP still prefills the field with the profile value and tags it estimé (the `hasEstimates` path is preserved). The RED state was real: the test failed to compile on the not-yet-defined `renteVsCapitalEmptyState` key, and the fiction assertions failed against the un-fixed screen.
- **GREEN (`45963a677`)**:
  - **Controllers start empty** (`rente_vs_capital_screen.dart:69-85`): `_ageCtrl`, `_salaryCtrl`, `_lppTotalCtrl`, `_capitalObligCtrl`, `_capitalSurobCtrl`, `_renteCtrl` no longer carry seeded text. The only fill path is `_autoFillFromProfile` (ProfileDataSource-tagged). `_tcObligCtrl` (6.8) / `_tcSurobCtrl` (5.0) kept as statutory LPP conversion-rate minima.
  - **Compute-guard** `_hasUsableInputs` + early return in `_recalculateAsync`: when no usable LPP input exists, the prior result is cleared and the engine is never called — so no projection renders on a phantom avoir. Removed the engine fiction fallbacks (`?? 350000 / 500000 / 150000 / 37000` → `?? 0`).
  - **Empty state** `_buildEmptyStateHint()`: an explicit `Semantics(label:)`-wrapped card rendering `renteVsCapitalEmptyState` (« Complète ton profil ou saisis tes valeurs pour lancer la simulation. ») in both estimate and certificate modes when `!_hasUsableInputs`. New ARB key added ×6 (fr/en/de/es/it/pt), `flutter gen-l10n` regenerated, ARB parity 6/6, FR accents correct, no banned terms.

### Task 2 — Maestro gate GREEN + design panel + device capture — commit `97ac91387`

Device-verified on **iPhone 16e simulator, iOS 26.2**, debug `--no-codesign` build (`.nosync` xattr-strip doctrine applied before the rebuild — see Build Constraint Note):

- `maestro test bug__ILLOG01__rvc_fiction_defaults.yaml` — **EXIT 0 COLD** (post sim-reboot, `/tmp/illog01_cold.log`) AND **EXIT 0 WARM** (`/tmp/illog01_warm.log`): `Assert "Rente ou capital.*"` COMPLETED, `Assert "Estimer pour moi"` COMPLETED, `Assert "350000" is not visible` COMPLETED, `Assert "100000" is not visible` COMPLETED.
- `maestro test bug__ILLOG02__rvc_ax_tree_empty.yaml` — **EXIT 0** (`/tmp/illog02_nonreg.log`): plan 09's AX-tree fix is non-regressed by this change.
- `idb ui describe-all` (AX engaged, post-deeplink): shows the empty-state copy `Complète ton profil ou saisis tes valeurs pour lancer la simulation.` and contains NO `350000` / `100000`.
- Device captures: `.planning/_walker/illogism-fixes/w3/w3-rvc-empty-state.png` (empty âge / salaire / LPP fields + empty-state card, NO « Capital estimé à 65 ans » phantom block) and `.planning/_walker/illogism-fixes/w3/w3-illog02-nonregression-ax.png`.
- No flow assertion change was needed — the fix made the screen *reach* the unchanged `assertNotVisible` guards (which the un-fixed screen could not, being gated by ILLOG-02).

## Mechanical Gates (0-TRUST citations)

- `cd apps/mobile && flutter test test/screens/rente_vs_capital_defaults_test.dart test/screens/rente_vs_capital_semantics_test.dart test/screens/arbitrage_screens_smoke_test.dart` → **33 passed** (4 defaults + 2 semantics + 27 arbitrage smoke).
- `cd apps/mobile && flutter analyze lib/screens/arbitrage/rente_vs_capital_screen.dart test/screens/rente_vs_capital_defaults_test.dart test/screens/arbitrage_screens_smoke_test.dart` → **No issues found**.
- ARB parity: `renteVsCapitalEmptyState` present 1× in each of the 6 ARB files.
- `python3 tools/checks/accent_lint_fr.py` — the new FR string and the screen are accent-clean (the 283 pre-existing violations are all in unrelated backend/tools files — out of scope, logged below).
- Acceptance grep `'50'|100000|350000|500000|150000|37000` in the screen → only 2 unrelated survivors: `clamp(0, 5000000)` (coach-prefill upper bound) and the CHF formatter's `1000000` magnitude threshold. ZERO fiction defaults remain.

## Design Panel (modified screen, per feedback_design_panel_before_push)

4-lens panel applied to the diff before push:
- **UX** — PASS: replaces silent fiction with an honest, actionable « tu »-voice invitation; the user never sees an invented projection as their data. Verified on device (screenshot).
- **a11y** — PASS: empty-state hint is a discrete AX node (`Semantics(label:)` + inner `ExcludeSemantics`), surfaces in `idb describe-all`; ILLOG-02 AX tree non-regressed (flow GREEN).
- **Adversarial** — PASS: fiction values absent from BOTH widget tree (`findsNothing`) and device AX tree; the `_hasUsableInputs` guard provably prevents any phantom projection; the `hasEstimates` prefill path is preserved (test).
- **Engineering/wiring** — PASS: surgical diff (no `_calculate*` / financial_core boundary touched, Karpathy #3), MintColors throughout, no new dependencies, no banned terms.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Two smoke tests encoded the old fiction behavior**
- **Found during:** Task 1 GREEN verification.
- **Issue:** `arbitrage_screens_smoke_test.dart` had `has default LPP total input pre-filled` asserting `'350'` was pre-filled (the exact fiction being removed), and `renders reachable semantic disclaimer and legal sources` relied on a result that only computed because of the fiction default.
- **Fix:** rewrote the first to assert the new correct behavior (no '350000', empty-state shown); seeded the second with a profile carrying a real LPP (`_debtPriorityProfile()`, avoirLppTotal 300000) so a result legitimately computes.
- **Files modified:** `apps/mobile/test/screens/arbitrage_screens_smoke_test.dart`
- **Commit:** `45963a677`

### Out-of-scope (logged, NOT fixed — SCOPE BOUNDARY)
- `accent_lint_fr.py` reports 283 pre-existing accent violations, ALL in unrelated files (`services/backend/app/services/mortgage/*`, `services/backend/app/services/unemployment/*`, `tools/simulator/*` docs). None in any file this plan touched. Not fixed — outside the current task's surface.

## Known Stubs
None. With a usable LPP the screen renders real engine-computed values (offline `ArbitrageEngine` fallback confirmed working). Without one, the explicit empty state is the intended terminal state — not a stub.

## Threat Surface
Closes the plan's threat register entry **T-ILF-10-01** (Tampering / intégrité — « une projection sur données fictives présentée comme réelle »): the fiction defaults are removed, ProfileDataSource is the only input path, and a permanent regression flow (`bug__ILLOG01`) + widget test guard against reintroduction. No new network endpoints, auth paths, or schema changes.

## Build Constraint Note
The `.nosync` iCloud mount re-applies provenance xattrs that break codesign during `flutter build ios --simulator`; an `xattr -cr .` + `dot_clean -m .` strip before the rebuild (consistent with plan 09 and the walker's `--no-codesign` doctrine) produced a clean build (EXIT 0, `/tmp/illog01_build.log`) and the device-green citations above.

## Self-Check: PASSED
- Created file present: `apps/mobile/test/screens/rente_vs_capital_defaults_test.dart` — FOUND
- Modified files present: `rente_vs_capital_screen.dart`, 6 ARB files, `arbitrage_screens_smoke_test.dart`, `_INDEX.md`, `VALIDATION.md` — FOUND
- Commits present: `4068ba429` (test/RED), `45963a677` (feat/GREEN), `97ac91387` (test/gate) — FOUND
- Device captures present: `w3-rvc-empty-state.png`, `w3-illog02-nonregression-ax.png` — FOUND
- Maestro ILLOG01 EXIT 0 cold + warm; ILLOG02 EXIT 0 non-regression; `flutter analyze` 0 issues; 33 widget tests green; ARB parity 6/6; 0 fiction defaults remain.
