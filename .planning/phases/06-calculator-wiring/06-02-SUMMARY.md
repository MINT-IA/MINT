---
phase: 06-calculator-wiring
plan: 02
subsystem: flutter-calculators
tags: [prefill, write-back, coach-profile, i18n, smart-default-indicator]
dependency_graph:
  requires: [06-01]
  provides: [CAL-01-prefill, CAL-03-writeback]
  affects: [CoachProfileProvider, FinancialPlanProvider]
tech_stack:
  added: [PrevoyanceProfile.copyWith, PatrimoineProfile.mortgageCapacity, PatrimoineProfile.estimatedMonthlyPayment]
  patterns: [GoRouter-extra-prefill, _hasUserInteracted-guard, SmartDefaultIndicator-badge, snackbar-confirmation]
key_files:
  created:
    - apps/mobile/test/screens/calculator_prefill_writeback_test.dart
  modified:
    - apps/mobile/lib/screens/arbitrage/rente_vs_capital_screen.dart
    - apps/mobile/lib/screens/mortgage/affordability_screen.dart
    - apps/mobile/lib/screens/simulator_3a_screen.dart
    - apps/mobile/lib/screens/lpp_deep/rachat_echelonne_screen.dart
    - apps/mobile/lib/screens/lpp_deep/epl_screen.dart
    - apps/mobile/lib/screens/pillar_3a_deep/retroactive_3a_screen.dart
    - apps/mobile/lib/models/coach_profile.dart
    - apps/mobile/lib/l10n/app_fr.arb
    - apps/mobile/lib/l10n/app_en.arb
    - apps/mobile/lib/l10n/app_de.arb
    - apps/mobile/lib/l10n/app_es.arb
    - apps/mobile/lib/l10n/app_it.arb
    - apps/mobile/lib/l10n/app_pt.arb
decisions:
  - "PrevoyanceProfile.copyWith() added as it was missing and required for write-back (Rule 2)"
  - "PatrimoineProfile gains mortgageCapacity + estimatedMonthlyPayment for /hypotheque write-back"
  - "_writeBackResult() uses Future.delayed(500ms) in rente_vs_capital to let async recalculation settle before writing"
  - "retroactive_3a_screen gains _hasUserInteracted flag (was missing — added per plan requirement)"
  - "salaireBrut from GoRouter prefill is monthly — all screens multiply by 13 for annual"
metrics:
  duration: ~90min
  completed: 2026-04-06
  tasks_completed: 2
  files_changed: 21
---

# Phase 06 Plan 02: Calculator Prefill + Write-Back Summary

**One-liner:** GoRouter prefill consumption with SmartDefaultIndicator badges on 5 calculator screens, plus `_writeBackResult()` on all 6 screens writing computed results back to CoachProfile with snackbar confirmation and infinite-loop guards.

## Tasks Completed

### Task 1: _applyPrefill() + SmartDefaultIndicator on 5 calculator screens

All 5 target screens (epl_screen already had it) now consume `GoRouter extra['prefill']` maps:

| Screen | Prefill keys consumed | Badge shown |
|--------|-----------------------|-------------|
| rente_vs_capital | avoirLpp, tauxConversion, salaireBrut (×13), ageRetraite | lpp_total, salaire_brut, lpp_obligatoire, ageRetraite |
| affordability | salaireBrut (×13), epargne, avoirLpp + _initializeFromProfile() | revenu_brut, avoir_lpp, epargne_dispo |
| simulator_3a | salaireBrut (×13 → marginalRate), canton | via existing _isPreFilled indicator |
| rachat_echelonne | salaireBrut (×13), rachatMaximum, avoirLpp | avoir_lpp, rachat_max |
| retroactive_3a | salaireBrut (→ tauxMarginal derivation), canton | taux_marginal |

**Key fix:** `affordability_screen` had hardcoded defaults (120,000 / 200,000). Added `_initializeFromProfile()` to replace them from CoachProfile.

**Commit:** `4605aa4d`

### Task 2: _writeBackResult() on all 6 screens + model extensions + i18n + tests

**Model extensions (coach_profile.dart):**
- `PrevoyanceProfile.copyWith()` — added (was missing, required for write-back)
- `PatrimoineProfile.mortgageCapacity` + `estimatedMonthlyPayment` — new fields for /hypotheque write-back

**Write-back per screen:**

| Screen | Fields written back |
|--------|---------------------|
| rente_vs_capital | prevoyance.projectedRenteLpp, projectedCapital65, targetRetirementAge |
| affordability | patrimoine.mortgageCapacity, estimatedMonthlyPayment |
| simulator_3a | write-back on every _calculate() when _hasUserInteracted==true |
| rachat_echelonne | triggers on _onInputChanged() |
| epl_screen | triggers on montantSouhaite slider change |
| retroactive_3a | triggers on chip/dropdown interaction |

**i18n:** 8 keys added to 6 languages (FR/EN/DE/ES/IT/PT):
- `profileUpdatedSnackbar`, `profileUpdateErrorSnackbar`
- `prefillBadgeTitle`, `prefillBadgeSourceLabel`, `prefillSourceEstimated`, `prefillSourceUserInput`, `prefillBadgePrecise`, `calculatorNoPrefillBody`

**Tests:** 19 tests in `calculator_prefill_writeback_test.dart` covering:
- PatrimoineProfile copyWith + roundtrip JSON for new fields
- PrevoyanceProfile copyWith for write-back fields
- salaireBrut monthly×13=annual conversion (Julien test case: 9400×13=122200)
- Screen smoke tests (renders without crash) for 4 screens
- _hasUserInteracted guard logic

**Commit:** `21d23625`

## Deviations from Plan

### Auto-added Missing Critical Functionality

**1. [Rule 2 - Missing] PrevoyanceProfile.copyWith() added**
- **Found during:** Task 2 — write-back requires copyWith on prevoyance
- **Issue:** PrevoyanceProfile had no copyWith method; all other sub-models had it
- **Fix:** Added full copyWith with all 24 fields, consistent with PatrimoineProfile pattern
- **Files modified:** apps/mobile/lib/models/coach_profile.dart
- **Commit:** 21d23625

**2. [Rule 2 - Missing] retroactive_3a_screen._hasUserInteracted flag**
- **Found during:** Task 2 — plan required _hasUserInteracted guard
- **Issue:** Screen had no _hasUserInteracted flag (unlike the other 5 screens)
- **Fix:** Added bool _hasUserInteracted = false, set in user interaction callbacks
- **Files modified:** apps/mobile/lib/screens/pillar_3a_deep/retroactive_3a_screen.dart
- **Commit:** 21d23625

**3. [Rule 1 - Bug] affordability_screen hardcoded defaults replaced**
- **Found during:** Task 1 — plan explicitly noted hardcoded 120000/200000
- **Fix:** Added _initializeFromProfile() that reads from CoachProfile
- **Files modified:** apps/mobile/lib/screens/mortgage/affordability_screen.dart
- **Commit:** 4605aa4d

## Known Stubs

None — all prefill consumption and write-back are wired to real CoachProfile fields. SmartDefaultIndicator badges appear when _prefilledFields Set contains the field key (populated by _applyPrefill).

## Threat Flags

None new. All write-back fields were already in CoachProfile scope. The clamping in `_applyPrefill` (avoirLpp: 0-5M, tauxConversion: 0.01-0.10, ageRetraite: 58-70) mitigates T-06-03 (Tampering). The `_hasUserInteracted` guard mitigates T-06-04 (infinite loop).

## Self-Check: PASSED

All key files found. Both commits verified in git history.

| Check | Result |
|-------|--------|
| rente_vs_capital_screen.dart | FOUND |
| affordability_screen.dart | FOUND |
| coach_profile.dart (with PrevoyanceProfile.copyWith) | FOUND |
| calculator_prefill_writeback_test.dart | FOUND |
| commit 4605aa4d (Task 1) | FOUND |
| commit 21d23625 (Task 2) | FOUND |
