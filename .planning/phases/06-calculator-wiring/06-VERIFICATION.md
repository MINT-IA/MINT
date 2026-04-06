---
phase: 06-calculator-wiring
verified: 2026-04-06T09:00:00Z
status: human_needed
score: 3/3 must-haves verified
gaps: []
deferred: []
human_verification:
  - test: "Open /rente-vs-capital via a coach RouteSuggestionCard tap while Julien's profile (avoirLppTotal: 70377) is loaded. Inspect the LPP capital field."
    expected: "The field shows 70,377 CHF pre-filled without any user typing. SmartDefaultIndicator badge is visible next to the label."
    why_human: "Requires live device/simulator with real CoachProfile state and an actual coach tool call producing a route_to_screen with avoirLpp in prefill. Cannot simulate the full GoRouter extra round-trip in a grep check."
  - test: "After running the rente vs. capital simulation (change one value then tap Calculer), check CoachProfile state."
    expected: "projectedRenteLpp and projectedCapital65 fields are updated in CoachProfile, and a 'Profil mis à jour' snackbar appears briefly."
    why_human: "Write-back behavior is conditional on _hasUserInteracted and async recalculation settling — cannot verify snackbar + state update without running the app."
  - test: "Open /hypotheque via coach suggestion with a profile containing salaireBrutMensuel and epargneLiquide. Confirm revenue brut and épargne fields are pre-filled from profile (not showing hardcoded 120,000 / 200,000 defaults)."
    expected: "Fields reflect actual CoachProfile values, not hardcoded constants."
    why_human: "Requires live CoachProfile context to distinguish profile-loaded values from defaults."
---

# Phase 6: Calculator Wiring Verification Report

**Phase Goal:** Every calculator screen opened via a coach suggestion arrives pre-filled with data MINT already knows — users are never asked to re-enter information the app has
**Verified:** 2026-04-06T09:00:00Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Opening /rente-vs-capital via a coach suggestion shows Julien's 70,377 CHF LPP capital pre-filled | ✓ VERIFIED (code) / ? HUMAN (runtime) | `_applyPrefill` at line 324 of `rente_vs_capital_screen.dart` reads `prefill['avoirLpp']` and sets `_lppTotalCtrl.text` with `.clamp(0, 5000000)`. Test at `widget_renderer_test.dart:188` confirms `avoirLpp: 70377` passes through to `RouteSuggestionCard`. Test at `calculator_prefill_writeback_test.dart:171` confirms 70377 passes clamp unchanged. Runtime verification needed for end-to-end visual confirmation. |
| 2 | A RouteSuggestionCard tap passes prefill data through GoRouter extras to the calculator constructor | ✓ VERIFIED | `route_suggestion_card.dart:89` — `context.push(route, extra: prefill)`. `widget_renderer.dart` merges backend + RoutePlanner prefill into `mergedPrefill` and passes it as `prefill:` to `RouteSuggestionCard`. All 6 calculator screens read `GoRouterState.of(context).extra` then call `_applyPrefill()`. |
| 3 | When a calculator produces a result, the relevant field (e.g., projected LPP capital) is written back to CoachProfile | ✓ VERIFIED (code) / ? HUMAN (runtime) | `rente_vs_capital_screen.dart:277-315` — `_writeBackResult()` reads `_result!.renteNetMensuelle` and `_result!.capitalProjecte`, calls `provider.updateProfile(updated)`. `_hasUserInteracted` guard prevents spurious writes. Test `calculator_prefill_writeback_test.dart:226` verifies guard logic. Runtime snackbar confirmation needs human verification. |

**Score:** 3/3 truths verified at code level

### Deferred Items

None.

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `services/backend/app/services/coach/coach_tools.py` | `prefill` field in `route_to_screen` input_schema | ✓ VERIFIED | Line 312: `"prefill": {"type": "object", "additionalProperties": True, ...}`. NOT in `required` list (line 325: `["intent", "confidence", "context_message"]`). |
| `apps/mobile/lib/widgets/coach/widget_renderer.dart` | Flutter-side prefill injection via RoutePlanner | ✓ VERIFIED | Lines 89-133: reads `backendPrefill`, instantiates `RoutePlanner`, merges with `{...decision.prefill!, if (backendPrefill != null) ...backendPrefill}`, passes `mergedPrefill` to `RouteSuggestionCard`. |
| `apps/mobile/lib/screens/arbitrage/rente_vs_capital_screen.dart` | GoRouter extra prefill consumption + write-back | ✓ VERIFIED | `_applyPrefill` at line 324, `_writeBackResult` at line 277, `_hasUserInteracted` at line 106, `SmartDefaultIndicator` at lines 649, 920, 1115. |
| `apps/mobile/lib/screens/mortgage/affordability_screen.dart` | Profile auto-fill + GoRouter extra prefill + write-back | ✓ VERIFIED | `_initializeFromProfile` at line 55, `_applyPrefill` at line 106, `_writeBackResult` at line 135, `SmartDefaultIndicator` at line 562. Hardcoded defaults replaced. |
| `apps/mobile/lib/screens/simulator_3a_screen.dart` | GoRouter extra prefill path + write-back | ✓ VERIFIED | `_applyPrefill` at line 87, `_writeBackResult` at line 255. |
| `apps/mobile/lib/screens/lpp_deep/rachat_echelonne_screen.dart` | GoRouter extra prefill path + write-back | ✓ VERIFIED | `_applyPrefill` at line 178, `_writeBackResult` at line 220. |
| `apps/mobile/lib/screens/lpp_deep/epl_screen.dart` | Write-back (prefill pre-existing) | ✓ VERIFIED | `_writeBackResult` at line 93. Pre-existing `_applyPrefill` unchanged. |
| `apps/mobile/lib/screens/pillar_3a_deep/retroactive_3a_screen.dart` | GoRouter extra prefill path + write-back | ✓ VERIFIED | `_applyPrefill` at line 137, `_writeBackResult` at line 148, `_hasUserInteracted` added. |
| `apps/mobile/lib/models/coach_profile.dart` | `PrevoyanceProfile.copyWith()` + new `PatrimoineProfile` fields | ✓ VERIFIED | `PrevoyanceProfile.copyWith` at line 443. `mortgageCapacity` at line 680, `estimatedMonthlyPayment` at line 681. Both in `fromJson`, `copyWith`, `toJson`. |
| `apps/mobile/test/screens/calculator_prefill_writeback_test.dart` | 19 tests covering prefill and write-back | ✓ VERIFIED | File exists. All 19 tests pass (confirmed by test run). Covers `PrevoyanceProfile.copyWith`, `PatrimoineProfile` JSON round-trip, salaireBrut×13=annual, screen smoke tests, `_hasUserInteracted` guard. |
| `apps/mobile/test/widgets/coach/widget_renderer_test.dart` | Prefill pipeline tests (T-06-01 group) | ✓ VERIFIED | 4 tests in group `prefill pipeline (T-06-01)`. All 12 tests in file pass. |
| `services/backend/tests/test_coach_tools.py` | prefill schema validation tests | ✓ VERIFIED | `test_route_to_screen_has_prefill_field` and `test_route_to_screen_prefill_not_in_required` at lines 134-148. All 38 tests pass. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `coach_tools.py` | `widget_renderer.dart` | `prefill` key in tool call JSON | ✓ WIRED | Backend adds `prefill` to `route_to_screen` schema; Flutter reads `p['prefill']` from tool call input. |
| `widget_renderer.dart` | `route_suggestion_card.dart` | `prefill:` constructor param | ✓ WIRED | `widget_renderer.dart:133` — `prefill: mergedPrefill` passed to `RouteSuggestionCard`. |
| `route_suggestion_card.dart` | calculator screens | `context.push(route, extra: prefill)` | ✓ WIRED | `route_suggestion_card.dart:89` — prefill sent as GoRouter extra on tap. |
| `rente_vs_capital_screen.dart` | `coach_profile_provider.dart` | `updateProfile()` in `_writeBackResult()` | ✓ WIRED | `rente_vs_capital_screen.dart:296` — `provider.updateProfile(updated)` with real computed `_result!.renteNetMensuelle`. |
| `affordability_screen.dart` | `coach_profile_provider.dart` | `updateProfile()` in `_writeBackResult()` | ✓ WIRED | `affordability_screen.dart:153` — `provider.updateProfile(updated)` with real computed mortgage capacity. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|-------------------|--------|
| `rente_vs_capital_screen.dart` | `_result!.renteNetMensuelle`, `_result!.capitalProjecte` | `_recalculate()` — calls `LppCalculator.projectToRetirement()` | Yes — computed from TextController inputs and LPP calculator, not static | ✓ FLOWING |
| `affordability_screen.dart` | `_revenuBrut` | `_initializeFromProfile()` reads `profile.salaireBrutMensuel * profile.nombreDeMois` | Yes — live profile values | ✓ FLOWING |
| `widget_renderer.dart` | `mergedPrefill` | `RoutePlanner.plan(intent)` + `backendPrefill` from LLM tool call | Yes — RoutePlanner reads real `CoachProfile` fields via `_resolveProfileValue()` | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Backend `prefill` in properties, NOT in required | `python3 -m pytest services/backend/tests/test_coach_tools.py -v` | 38 passed | ✓ PASS |
| Flutter prefill pipeline tests pass | `flutter test test/widgets/coach/widget_renderer_test.dart` | 12 passed | ✓ PASS |
| Calculator prefill + write-back tests pass | `flutter test test/screens/calculator_prefill_writeback_test.dart` | 19 passed | ✓ PASS |
| End-to-end GoRouter extra round-trip (live device) | Requires running app | Cannot test without simulator | ? SKIP |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| CAL-01 | 06-02-PLAN.md | Calculator screens pre-fill all known fields from CoachProfile | ✓ SATISFIED | `_initializeFromProfile()` + `_applyPrefill()` on all 6 screens; `affordability_screen.dart` hardcoded defaults (120,000/200,000) replaced. |
| CAL-02 | 06-01-PLAN.md | RoutePlanner.prefill decisions passed through GoRouter extras to calculator constructors | ✓ SATISFIED | Full pipeline: backend schema → `widget_renderer.dart` merge → `RouteSuggestionCard` → `context.push(extra: prefill)` → screen `GoRouterState.of(context).extra`. |
| CAL-03 | 06-02-PLAN.md | Calculator results feed back into CoachProfile (bidirectional data flow) | ✓ SATISFIED | `_writeBackResult()` on all 6 screens, guarded by `_hasUserInteracted`. `PrevoyanceProfile.copyWith()` added to enable write-back. New `PatrimoineProfile.mortgageCapacity` + `estimatedMonthlyPayment` fields. |

No orphaned requirements: REQUIREMENTS.md maps only CAL-01, CAL-02, CAL-03 to Phase 6, and all three are claimed and implemented.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `pulse_screen.dart` (pre-existing) | Multiple | Undefined getters (`cap`, `capImpact`, `activeGoal`, `monthlyFree`) | ⚠️ Warning | Pre-existing from Phase 5. Not introduced by Phase 6. Last modified in `feat(05-02)` commit. Does not affect calculator wiring goal. |
| `retirement_budget_service.dart` (pre-existing) | 83-89 | Undefined named parameters (`monthlyIncome`, `lppMonthly`, etc.) | ⚠️ Warning | Pre-existing. Not touched by Phase 6 commits. |

Phase 6 files (widget_renderer, rente_vs_capital, affordability, simulator_3a, rachat_echelonne, epl_screen, retroactive_3a, coach_tools) are **clean** — zero TODO/FIXME/placeholder patterns found.

### Human Verification Required

#### 1. Prefill Visual Confirmation — /rente-vs-capital

**Test:** Load Julien's profile (avoirLppTotal: 70,377). In chat, trigger a coach suggestion that calls `route_to_screen` with `intent: 'lpp_buyback'` or `intent: 'retirement_planning'`. Tap the RouteSuggestionCard. Observe the LPP capital field.
**Expected:** The field displays "70,377" (or "70377") pre-filled without the user typing. A SmartDefaultIndicator badge is visible next to the field label ("Depuis ton profil MINT").
**Why human:** Requires live device with CoachProfile loaded and an actual coach tool call. Cannot verify visual badge placement and field value display via grep.

#### 2. Write-Back Snackbar + State Update

**Test:** On /rente-vs-capital, change one field (e.g., adjust age de retraite), then tap Calculer. After results appear, wait ~500ms.
**Expected:** A green snackbar reads "Profil mis à jour" and appears for ~2.5s. In debug mode, inspect CoachProfile — `prevoyance.projectedRenteLpp` and/or `projectedCapital65` reflect the computed values.
**Why human:** Snackbar display and async state update timing cannot be verified without running the app.

#### 3. Affordability Screen Hardcoded Default Replacement

**Test:** Open /hypotheque from a fresh session with a CoachProfile containing `salaireBrutMensuel: 9400` (Julien: 9,400/month). Observe the "Revenu brut annuel" field default.
**Expected:** Field shows 122,200 CHF (9,400 × 13), NOT the old hardcoded 120,000 CHF. No SmartDefaultIndicator badge for this field (profile-initialized, not GoRouter-prefilled).
**Why human:** Distinguishing profile-initialized from hardcoded requires live profile context.

### Gaps Summary

No gaps found. All three CAL requirements are implemented, wired, and tested. The phase goal is achieved at code level — every calculator screen opened via a coach suggestion has the structural machinery to arrive pre-filled with data MINT already knows.

The three human verification items are behavioral/visual runtime checks that cannot be confirmed programmatically. They do not indicate missing implementation — they confirm correct runtime behavior of verified code paths.

---

_Verified: 2026-04-06T09:00:00Z_
_Verifier: Claude (gsd-verifier)_
