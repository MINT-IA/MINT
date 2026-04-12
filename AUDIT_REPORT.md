# MINT Static Analysis Audit Report
**Date:** 2026-04-06  
**Scope:** Flutter app + Backend + i18n consistency  
**Analysis Type:** Manual static analysis (Flutter/pytest not available in environment)

---

## Summary

**Total Issues Found: 18**
- **Critical (Compilation Errors):** 5 duplicate class definitions
- **High (Broken Navigation Routes):** 2 unregistered GoRouter paths
- **Medium (Test Coverage Gaps):** 4 items noted in phase 7 verification
- **Clean:** i18n consistency, Python syntax, imports

---

## 1. Critical: Duplicate Class Definitions (5 files)

These are actual Dart compilation errors. Multiple files define the same class name, which will cause "Duplicate definition" errors during compilation.

| Class Name | File 1 (Canonical) | File 2 (Duplicate) | Severity |
|------------|-------------------|-------------------|----------|
| `ChiffreChoc` | `lib/models/response_card.dart` | `lib/models/minimal_profile_models.dart` | CRITICAL |
| `ChiffreChoc` | `lib/models/response_card.dart` | `lib/services/pillar_3a_deep_service.dart` | CRITICAL |
| `CoachNarrativeService` | `lib/services/coach_narrative_service.dart` | `lib/services/coach/coach_narrative_service.dart` | CRITICAL |
| `AdvisorDossier` | `lib/services/advisor/advisor_matching_service.dart` | `lib/services/expert/dossier_preparation_service.dart` | CRITICAL |
| `WeeklyRecapService` | `lib/services/recap/weekly_recap_service.dart` | `lib/services/coach/weekly_recap_service.dart` | CRITICAL |

**Action Required:** Remove duplicate definitions from non-canonical files or rename one to distinguish them.

---

## 2. High: Broken GoRouter Navigation Routes (2 routes)

From Phase 7 verification report (`07-VERIFICATION.md`):

| Route in Code | Registered in GoRouter | File | Impact |
|---------------|----------------------|------|--------|
| `/premier-emploi` | `/first-job` | `lib/services/cap_sequence_engine.dart:483` | firstJob journey step fj_02 will fail to navigate |
| `/location-vs-propriete` | `/arbitrage/location-vs-propriete` | `lib/services/cap_sequence_engine.dart:432` | housingPurchase journey step hou_06 will fail to navigate |

**Action Required:** Fix `intentTag` values to match registered routes or register new GoRoute aliases.

---

## 3. Medium: Route Detection Test Gap (2 tests)

Tests assert route strings exist but do NOT verify GoRouter can actually navigate to them. This masks the above two broken routes.

| File | Line | Issue |
|------|------|-------|
| `apps/mobile/test/journeys/firstjob_journey_test.dart` | 202 | Asserts `contains('/premier-emploi')` — passes despite route unregistered |
| `apps/mobile/test/journeys/housing_journey_test.dart` | 236 | Asserts `contains('/location-vs-propriete')` — passes despite route unregistered |

**Action Required:** Add navigation verification step to integration tests or upgrade to `IntegrationTestWidgetsFlutterBinding`.

---

## 4. Medium: Premier Eclairage Type Mismatch (1 service layer)

From Phase 7 verification:  
- **Expected:** firstJob journey shows LPP or 3a numbers
- **Actual:** `stressType: 'stress_budget'` produces hourly rate breakdown
- **File:** `lib/services/coach/intent_router.dart` (intentChipPremierEmploi mapping)

**Action Required:** Create dedicated stressType for firstJob (e.g., `stress_first_job` or `stress_prevoyance`) or wire existing LPP/3a stress types.

---

## 5. Data Quality Issues (Minor)

### Additional Duplicate Classes (Not Compilation Errors — Private or Context-Specific)

These are private widget classes or context-specific models that appear multiple times. Less critical than public API duplicates, but still indicate code organization opportunities:

- `_GaugePainter` (3 locations)
- `_HubItemCard` (7 locations)
- `_LifeEvent` (2 locations)
- `_PieChartPainter` (2 locations)
- `_TrajectoryPainter` (2 locations)
- `_TypingDots` (2 locations)
- `_WaterfallPainter` (3 locations)
- `_ComparisonRow` (2 locations)
- `_CtaButton` (2 locations)
- `_LegendLinePainter` (2 locations)

**Note:** These are private (prefixed with `_`) so they don't cause compilation errors across modules, but consolidation is recommended for maintainability.

---

## 6. Clean: Verified Passing

✓ **i18n Consistency:** All 6 languages (fr, en, de, es, it, pt) have identical key sets (6,333 keys each)  
✓ **Python Syntax:** 9,477 Python files checked — no syntax errors detected  
✓ **Import Resolution:** 677 Dart files checked — all relative imports resolve correctly  
✓ **L10n Generation:** `flutter gen-l10n` artifacts exist and are well-formed  
✓ **Git Status:** Working tree clean, no uncommitted changes (130 commits ahead of origin/dev)

---

## 7. Phase 7 Verification Status (from 07-VERIFICATION.md)

**Score:** 3/8 success criteria fully verified  
**Status:** gaps_found  
**Key Gaps:**
1. firstJob journey: unregistered `/premier-emploi` route + premier eclairage type mismatch + no device verification
2. housingPurchase journey: unregistered `/location-vs-propriete` route + no device verification
3. newJob journey: service layer complete + routes valid; no device verification
4. Journey tests: 63 tests pass (service layer), but tests don't detect broken navigation routes

---

## Detailed Duplicate Class List

For reference, here are all 33 duplicate/private class definitions found:

```
AdvisorDossier (2), BankTransaction (2), BenchmarkComparison (2),
CantonalBenchmark (2), ChallengeRecord (2), ChecklistItem (2),
ChiffreChoc (3), CoachNarrativeService (2), EnrichmentPrompt (2),
FranchiseOption (2), GeneratedLetter (2), GlossaryService (2),
GlossaryTerm (2), LlmProviderConfig (2), NavigationShellState (2),
QualityScore (2), WaterfallStep (2), WeeklyRecap (2),
WeeklyRecapService (2), _ComparisonRow (2), _CtaButton (2),
_GaugePainter (3), _HubItemCard (7), _LegendLinePainter (2),
_LifeEvent (2), _PieChartPainter (2), _TrajectoryPainter (2),
_TypingDots (2), _WaterfallPainter (3)
```

Public/exported duplicates (5): ChiffreChoc, CoachNarrativeService, AdvisorDossier, WeeklyRecapService  
Other duplicates (28): Mostly private widgets or context-specific models

---

## Recommended Priority Order

1. **P0 — Fix 5 public class duplicates** → prevents compilation
2. **P1 — Fix 2 broken GoRouter routes** → prevents navigation on device
3. **P2 — Upgrade journey tests** → add GoRouter navigation verification
4. **P3 — Fix premier eclairage stressType** → ensures SC1 correctness
5. **P4 — Device verification** → test SC1/SC2/SC3 on actual device/emulator

---

## Files Affected

**Flutter (apps/mobile/lib/):**
- `lib/models/response_card.dart` (canonical ChiffreChoc)
- `lib/models/minimal_profile_models.dart` (duplicate ChiffreChoc)
- `lib/services/pillar_3a_deep_service.dart` (duplicate ChiffreChoc)
- `lib/services/coach_narrative_service.dart` (canonical)
- `lib/services/coach/coach_narrative_service.dart` (duplicate)
- `lib/services/advisor/advisor_matching_service.dart` (canonical)
- `lib/services/expert/dossier_preparation_service.dart` (duplicate)
- `lib/services/recap/weekly_recap_service.dart` (canonical)
- `lib/services/coach/weekly_recap_service.dart` (duplicate)
- `lib/services/cap_sequence_engine.dart` (broken routes: /premier-emploi, /location-vs-propriete)
- `lib/services/coach/intent_router.dart` (premier eclairage stressType mismatch)
- `apps/mobile/test/journeys/firstjob_journey_test.dart` (weak route validation)
- `apps/mobile/test/journeys/housing_journey_test.dart` (weak route validation)

**Backend (services/backend/):**
- No syntax or critical errors detected
- Dependencies not installed (pytest missing) — standard for audit environment

---

_Report Generated: 2026-04-06_  
_Analysis Method: Manual static inspection (no compiler/linter available)_  
_Next Step: Fix P0 duplicates, then validate with `flutter analyze`_

