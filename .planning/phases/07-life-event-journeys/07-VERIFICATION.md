---
phase: 07-life-event-journeys
verified: 2026-04-06T09:00:00Z
status: human_needed
score: 6/8 must-haves verified
re_verification:
  previous_status: gaps_found
  previous_score: 3/8
  gaps_closed:
    - "fj_02_salary_xray intentTag fixed: '/premier-emploi' (unregistered) → '/first-job' (registered GoRouter path)"
    - "hou_06_compare intentTag fixed: '/location-vs-propriete' (unregistered) → '/arbitrage/location-vs-propriete' (registered GoRouter path)"
    - "intentChipPremierEmploi stressType fixed: 'stress_budget' → 'stress_prevoyance'; suggestedRoute fixed: '/premier-emploi' → '/first-job'; ChiffreChocSelector now has case 'stress_prevoyance' cascading to 3a tax saving > compound growth > retirement income"
    - "Journey tests updated: all 4 assertions in firstjob_journey_test.dart and 1 in housing_journey_test.dart now assert correct registered route strings; all 63 journey tests pass"
  gaps_remaining: []
  regressions: []
deferred:
  - truth: "firstJob, housingPurchase, and newJob journeys verified on device with a fresh profile"
    addressed_in: "Separate QA project"
    evidence: "User instruction: 'Gap 4 (verified on device) is explicitly deferred to a separate QA project — do not block on it'"
human_verification:
  - test: "newJob journey — device navigation and pre-fill"
    expected: "Tap 'Je change de travail' chip → CapSequence builds 5 steps → all route taps navigate successfully (/rente-vs-capital, /rachat-lpp, /pilier-3a) → nj_02 salary comparison opens pre-filled with existing profile salary data"
    why_human: "Routes appear valid in GoRouter but pre-fill behavior via Phase 6 RoutePlanner/GoRouter extras requires live confirmation. No automated test verifies actual navigation or pre-fill on device."
  - test: "firstJob premier eclairage — stress_prevoyance content on device"
    expected: "For a user with salary > 0 and taxSaving3a > 500, the premier eclairage card shows a 3a tax saving number (not an hourly rate); for a user aged < 35 with no 3a yet, it shows compound growth figures"
    why_human: "ChiffreChocSelector.case 'stress_prevoyance' logic is wired but the rendered ChiffreChoc card content has never been viewed on device. The cascade condition (taxSaving3a > 500) depends on profile enrichment; a fresh onboarding profile may fall through to compound growth or null. Screen rendering requires device confirmation."
---

# Phase 7: Life Event Journeys Verification Report

**Phase Goal:** Three complete user journeys — firstJob, housingPurchase, newJob — are verified end-to-end on device, with integration tests that fail if any link in the chain breaks
**Verified:** 2026-04-06T09:00:00Z
**Status:** human_needed
**Re-verification:** Yes — after gap closure plan 07-03 fixed 3 gaps (broken routes + stressType)

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | firstJob journey: intent → IntentRouter → CapSequence (5 steps) → premier eclairage with LPP/3a numbers → calculator routes wired | VERIFIED | IntentRouter maps `intentChipPremierEmploi` → `first_job` with `stress_prevoyance`; CapSequenceEngine `_buildFirstJob()` returns 5 steps; ChiffreChocSelector `case 'stress_prevoyance'` produces 3a/compound growth; 19 tests pass |
| 2 | housingPurchase journey: intent → IntentRouter → CapSequence (7 steps) → correct GoRouter routes for all steps | VERIFIED | `intentChipProjet` → `housing_purchase`; hou_06 intentTag is `/arbitrage/location-vs-propriete` (registered); 21 tests pass asserting correct routes |
| 3 | newJob journey: intent → IntentRouter → CapSequence (5 steps) → salary comparison, LPP transfer, 3a optimization routes | VERIFIED | `intentChipNouvelEmploi` → `new_job`; routes `/rente-vs-capital`, `/rachat-lpp`, `/pilier-3a` all registered in GoRouter; 23 tests pass |
| 4 | Each journey has integration tests that fail if any step produces no output or a broken navigation | PARTIAL | 63 flutter_test unit tests exist and pass; tests assert exact intentTag strings (now correct registered GoRouter paths); tests would catch a route string regression; tests are not IntegrationTestWidgetsFlutterBinding (no actual navigation executed) |
| 5 | IntentRouter resolves 9 chip keys including firstJob and newJob | VERIFIED | intent_router.dart has 9 entries; `intentChipPremierEmploi` → `first_job`; `intentChipNouvelEmploi` → `new_job`; no regression |
| 6 | CapSequenceEngine builds firstJob (5 steps) and newJob (5 steps) | VERIFIED | `_kGoalFirstJob` / `_kGoalNewJob` constants; step IDs fj_01..fj_05 and nj_01..nj_05 confirmed; no regression |
| 7 | IntentScreen shows 9 chips including 'Mon premier emploi' and 'Je change de travail' | VERIFIED | intent_screen.dart lines 74–81 add both chips before `intentChipAutre`; no regression |
| 8 | All 6 ARB files contain 22 new i18n keys (2 chips + 20 step titles/descriptions) | VERIFIED | app_fr.arb contains `intentChipPremierEmploi`, `intentChipNouvelEmploi`, `capStepFirstJob01Title`, `capStepNewJob01Title`; no regression |

**Score:** 6/8 truths verified (1 partial, 1 deferred to QA)

### Deferred Items

Items not yet met but explicitly addressed in later milestone phases.

| # | Item | Addressed In | Evidence |
|---|------|-------------|----------|
| 1 | All three journeys verified on device with a fresh profile (roadmap SCs 1-3 "verified on device" clause) | Separate QA project | User instruction at re-verification invocation: "Gap 4 (verified on device) is explicitly deferred to a separate QA project — do not block on it" |

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `apps/mobile/lib/services/coach/intent_router.dart` | 9 mappings; `intentChipPremierEmploi` with `stress_prevoyance` and suggestedRoute `/first-job` | VERIFIED | Line 72–75: goalIntentTag 'first_job', stressType 'stress_prevoyance', suggestedRoute '/first-job' |
| `apps/mobile/lib/services/cap_sequence_engine.dart` | fj_02 intentTag `/first-job`; hou_06 intentTag `/arbitrage/location-vs-propriete` | VERIFIED | Line 483: `intentTag: '/first-job'`; line 432: `intentTag: '/arbitrage/location-vs-propriete'` |
| `apps/mobile/lib/services/chiffre_choc_selector.dart` | `case 'stress_prevoyance'` dispatching to 3a tax saving > compound growth > retirement income | VERIFIED | Lines 115–127: case present with correct cascade logic using existing builder methods |
| `apps/mobile/lib/screens/onboarding/intent_screen.dart` | 9 intent chips including `intentChipPremierEmploi` and `intentChipNouvelEmploi` | VERIFIED | Lines 74–81 confirmed |
| `apps/mobile/test/journeys/firstjob_journey_test.dart` | Assertions use `/first-job` not `/premier-emploi`; stressType asserted as `stress_prevoyance` | VERIFIED | Lines 91, 98, 202, 212 all reference `/first-job` or `stress_prevoyance`; 19 tests pass |
| `apps/mobile/test/journeys/housing_journey_test.dart` | Assertion uses `/arbitrage/location-vs-propriete` not bare `/location-vs-propriete` | VERIFIED | Line 236: `expect(routes, contains('/arbitrage/location-vs-propriete'))`; 21 tests pass |
| `apps/mobile/test/journeys/newjob_journey_test.dart` | newJob E2E journey test, min 80 lines | VERIFIED | 436 lines, 23 tests, memory progression tests pass; no changes needed in gap closure |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `intent_screen.dart` | `intent_router.dart` | `IntentRouter.forChipKey('intentChipPremierEmploi')` | WIRED | Chip taps call `_onChipTap` → `IntentRouter.forChipKey(chip.chipKey)` |
| `intent_router.dart` | `cap_sequence_engine.dart` | goalIntentTag 'first_job' → `_buildFirstJob()` | WIRED | Switch dispatches on `_kGoalFirstJob` |
| `intent_router.dart` | `cap_sequence_engine.dart` | goalIntentTag 'new_job' → `_buildNewJob()` | WIRED | Switch dispatches on `_kGoalNewJob` |
| `cap_sequence_engine.dart` fj_02 | GoRouter `/first-job` | intentTag string | WIRED | Line 483: `intentTag: '/first-job'` — registered at app.dart line 510 |
| `cap_sequence_engine.dart` hou_06 | GoRouter `/arbitrage/location-vs-propriete` | intentTag string | WIRED | Line 432: `intentTag: '/arbitrage/location-vs-propriete'` — registered at app.dart line 805 |
| `intent_router.dart` intentChipPremierEmploi | `chiffre_choc_selector.dart` | stressType `stress_prevoyance` | WIRED | intent_router.dart line 74: `stressType: 'stress_prevoyance'`; chiffre_choc_selector.dart line 115: `case 'stress_prevoyance'` |
| `test/journeys/firstjob_journey_test.dart` | `IntentRouter` + `CapSequenceEngine` | direct service calls | WIRED | 19 tests pass; route assertions use registered paths |
| `test/journeys/housing_journey_test.dart` | `IntentRouter` + `CapSequenceEngine` | direct service calls | WIRED | 21 tests pass; route assertions use registered paths |
| `test/journeys/newjob_journey_test.dart` | `IntentRouter` + `CapSequenceEngine` | direct service calls | WIRED | 23 tests pass |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| `cap_sequence_engine.dart` firstJob steps | `profile.salaireBrutMensuel`, `prevoyance.avoirLppTotal`, `prevoyance.totalEpargne3a` | CoachProfile (user input) | Yes — real profile fields gate step completion | FLOWING |
| `chiffre_choc_selector.dart` stress_prevoyance | `profile.taxSaving3a`, `profile.age`, `profile.grossMonthlySalary` | MinimalProfile derived from CoachProfile | Yes — conditions drive cascade; builder methods use real financial calculations | FLOWING |
| `cap_sequence_engine.dart` housingPurchase steps | `profile.epargneLiquide`, `patrimoine.avoirLppTotal`, `salaireBrutMensuel` | CoachProfile (user input) | Yes — real fields gate completion and EPL eligibility (20k OPP2 minimum enforced) | FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| 63 journey tests pass | `flutter test test/journeys/` | All 63 tests passed | PASS |
| fj_02 uses registered route | `grep "intentTag: '/first-job'" cap_sequence_engine.dart` | Match at line 483 | PASS |
| hou_06 uses registered route | `grep "intentTag: '/arbitrage/location-vs-propriete'" cap_sequence_engine.dart` | Match at line 432 | PASS |
| No `/premier-emploi` in cap_sequence_engine.dart | `grep -c "premier-emploi" cap_sequence_engine.dart` | 0 matches | PASS |
| No bare `/location-vs-propriete` intentTag | `grep "location-vs-propriete" cap_sequence_engine.dart` (excluding /arbitrage prefix) | 0 matches | PASS |
| stress_prevoyance case in ChiffreChocSelector | `grep -n "case 'stress_prevoyance'" chiffre_choc_selector.dart` | Match at line 115 | PASS |
| IntentRouter stressType for firstJob | `grep -n "stress_prevoyance" intent_router.dart` | Match at line 74 | PASS |
| firstjob test asserts stress_prevoyance | `grep "stress_prevoyance" firstjob_journey_test.dart` | Match at line 91 | PASS |
| housing test asserts /arbitrage/ route | `grep "arbitrage/location-vs-propriete" housing_journey_test.dart` | Match at line 236 | PASS |
| flutter analyze — Phase 7 files | `flutter analyze --no-pub 2>&1` filtered to Phase 7 files | 0 errors in Phase 7 files | PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| LEJ-01 | 07-01, 07-02, 07-03 | firstJob journey verified end-to-end | SATISFIED (automated) | IntentRouter + CapSequence + routes all correct; premier eclairage uses stress_prevoyance for LPP/3a; 19 tests pass. Device verification deferred to QA project. |
| LEJ-02 | 07-01, 07-02, 07-03 | housingPurchase journey verified end-to-end | SATISFIED (automated) | All 7 CapSequence steps wired; hou_06 route fixed to `/arbitrage/location-vs-propriete`; 21 tests pass. Device verification deferred to QA project. |
| LEJ-03 | 07-01, 07-02 | newJob journey verified end-to-end | SATISFIED (automated) | CapSequence 5 steps; routes `/rente-vs-capital`, `/rachat-lpp`, `/pilier-3a` registered; 23 tests pass. Device verification deferred to QA project. |
| LEJ-04 | 07-02, 07-03 | Integration test for each journey | PARTIAL | 63 flutter_test unit tests exist, pass, and now assert correct registered GoRouter route strings. Tests are not `IntegrationTestWidgetsFlutterBinding` — they do not execute actual navigation. A route string regression would be caught; a GoRouter config regression would not. |

### Anti-Patterns Found

No new anti-patterns introduced by gap closure. Previously flagged anti-patterns (wrong route strings, wrong stressType) are confirmed fixed.

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `newjob_journey_test.dart` | 348, 366, 403, 421 | `prefer_const_declarations` (info) | Info | Pre-existing; no functional impact; not in Phase 7 gap scope |

### Human Verification Required

### 1. newJob Journey — Device Navigation and Pre-fill

**Test:** From a profile with salary data, tap 'Je change de travail' chip on IntentScreen. Follow the newJob CapSequence. Tap nj_02 (salary comparison step).
**Expected:** `/rente-vs-capital` opens and the salary field is pre-filled with the profile's existing monthly salary. All 5 step taps navigate without GoRouter error. nj_03 tap opens `/rachat-lpp`, nj_04 tap opens `/pilier-3a`.
**Why human:** Routes are registered in GoRouter and correct, but pre-fill via Phase 6 RoutePlanner extras requires live device confirmation. No automated test exercises actual navigation or GoRouter parameter passing.

### 2. firstJob Premier Eclairage — stress_prevoyance Content on Device

**Test:** From a fresh onboarding profile with a salary entered (e.g., 5000 CHF/month, age 28, canton VS), tap 'Mon premier emploi'. Observe the premier eclairage card that appears.
**Expected:** Card shows either a 3a tax saving amount (if `taxSaving3a > 500`) or a compound growth figure (if age < 35) — not an hourly wage breakdown. The number should be specific and LPP/3a-relevant.
**Why human:** The `case 'stress_prevoyance'` cascade is wired and uses existing builder methods, but the actual rendered card content (label, value, context string) has never been visually confirmed. The `taxSaving3a > 500` threshold behavior on a fresh profile (where `taxSaving3a` may be estimated from salary) needs live confirmation.

## Gaps Summary

**All 3 automated gaps from initial verification are closed:**

1. Route fix confirmed: `fj_02_salary_xray` intentTag is `/first-job` (registered). Zero occurrences of `/premier-emploi` in production code.
2. Route fix confirmed: `hou_06_compare` intentTag is `/arbitrage/location-vs-propriete` (registered). Zero bare `/location-vs-propriete` intentTags remain.
3. stressType fix confirmed: `intentChipPremierEmploi` uses `stress_prevoyance`; `ChiffreChocSelector` has a new substantive `case 'stress_prevoyance'` that cascades through 3a tax saving, compound growth, and retirement income — all backed by existing tested builder methods.
4. All 63 journey tests updated and passing with correct route string assertions.

**Remaining open items (human verification only):**

- newJob pre-fill behavior on device (Phase 6 RoutePlanner integration)
- firstJob premier eclairage rendered content on device (stress_prevoyance cascade output)
- Full device journey verification for all three journeys is explicitly deferred to a separate QA project per user instruction

**What is well-built:**
- All three journey service layers are substantive, wired, and tested
- IntentRouter 9-mapping expansion is correct
- CapSequenceEngine firstJob and newJob sequences use real profile data for step gating
- All 6 ARB files have correct i18n keys
- No broken GoRouter route strings remain in production code
- 63 test cases provide strong service-layer and route-string coverage

---

_Verified: 2026-04-06T09:00:00Z_
_Verifier: Claude (gsd-verifier)_
_Re-verification after: 07-03 gap closure_
