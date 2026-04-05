---
phase: 03-onboarding-pipeline
plan: 02
subsystem: onboarding-routing
tags: [intent-screen, cap-memory, chiffre-choc, premier-eclairage, onboarding-pipeline]
dependency_graph:
  requires:
    - IntentRouter.forChipKey (03-01)
    - ReportPersistenceService.savePremierEclairageSnapshot (03-01)
  provides:
    - IntentScreen._onChipTap fully wired: chipKey → IntentRouter → ChiffreChoc → CapMemory → /home?tab=0
    - CapMemoryStore.declaredGoals seeded with goalIntentTag after chip tap
    - PremierEclairage snapshot persisted after chip tap (consumed by Plan 03)
  affects:
    - apps/mobile/lib/screens/main_tabs/mint_home_screen.dart (plan 03 consumer of snapshot)
    - apps/mobile/lib/screens/coach/coach_chat_screen.dart (plan 03 consumer of chipKey intent)
tech_stack:
  added: []
  patterns:
    - Capture context refs before async gaps (use_build_context_synchronously)
    - etatCivil → householdType mapping via switch expression
    - Zero-valued MinimalProfileResult for pedagogical fallback (fresh install)
key_files:
  created: []
  modified:
    - apps/mobile/lib/screens/onboarding/intent_screen.dart
    - apps/mobile/test/screens/onboarding/intent_screen_test.dart
decisions:
  - "Capture CoachProfile and MinimalProfileResult before first await to satisfy use_build_context_synchronously lint — zero cost, correct pattern"
  - "CoachCivilStatus.marie|concubinage maps to householdType 'couple', all others to 'single' — conservative default for MinimalProfileService"
  - "CapSequenceEngine.build only called when CoachProfile non-null — fresh installs skip seeding gracefully (engine output not yet consumed by UI)"
metrics:
  duration: "~15 minutes"
  completed: "2026-04-05"
  tasks_completed: 2
  files_modified: 2
  tests_added: 5
---

# Phase 03 Plan 02: IntentScreen Rewiring Summary

**One-liner:** IntentScreen._onChipTap rewired to persist ARB chipKey, route via IntentRouter, compute premier eclairage via ChiffreChocSelector, seed CapMemoryStore.declaredGoals, and navigate to /home?tab=0 (Aujourd'hui).

## Tasks Completed

| Task | Description | Commit | Tests |
|------|-------------|--------|-------|
| 1 | Rewire IntentScreen._onChipTap with full pipeline | 6dda6ff9 | - |
| 2 | Add rewired pipeline tests; fix existing tests for chipKey behavior | ec64aa75 | +5 new, 14 total |

**Total: 14 tests green, flutter analyze 0 issues.**

## What Was Built

### Task 1: IntentScreen rewire (`apps/mobile/lib/screens/onboarding/intent_screen.dart`)

**_IntentChip class:**
- Added `final String chipKey` field (ARB identifier, e.g. `'intentChip3a'`)
- All 7 chip instantiations updated with explicit `chipKey:` argument
- Comments clarify chipKey vs label distinction (anti-pattern guard)

**_onChipTap pipeline (new sequence):**
1. `AnalyticsService().trackCTAClick(...)` — passes `chipKey` and `label`
2. Context refs captured before first `await`: `_buildMinimalProfile(context)` + `CoachProfileProvider.profile`
3. `setMiniOnboardingCompleted(true)` + `setSelectedOnboardingIntent(chip.chipKey)` — **chipKey stored, not label**
4. `IntentRouter.forChipKey(chip.chipKey)` → resolves `IntentMapping` (stressType, goalIntentTag, suggestedRoute)
5. `ChiffreChocSelector.select(profile, stressType: mapping.stressType)` → `ChiffreChoc` (always non-null)
6. `savePremierEclairageSnapshot({value, title, subtitle, colorKey, suggestedRoute, confidenceMode})` — display fields only
7. `CapMemoryStore.load()` → `copyWith(declaredGoals: [mapping.goalIntentTag])` → `CapMemoryStore.save(updated)`
8. `CapSequenceEngine.build(...)` — only when CoachProfile non-null (graceful skip for fresh installs)
9. `CoachEntryPayload` set in provider
10. `context.go('/home?tab=0')` — **Aujourd'hui, not Coach**

**_buildMinimalProfile helper:**
- Reads CoachProfile from provider; if `salaireBrutMensuel > 0`, calls `MinimalProfileService.compute()`
- Maps `CoachCivilStatus.marie|concubinage` → `'couple'`, others → `'single'`
- Falls back to zero-valued `MinimalProfileResult` with all 5 optional fields estimated → pedagogical mode

**New imports added:**
- `coach_profile.dart` (show CoachCivilStatus)
- `minimal_profile_models.dart`
- `coach_profile_provider.dart`
- `cap_memory_store.dart`
- `cap_sequence_engine.dart`
- `chiffre_choc_selector.dart`
- `coach/intent_router.dart`
- `minimal_profile_service.dart`

### Task 2: Tests (`apps/mobile/test/screens/onboarding/intent_screen_test.dart`)

**Test setup updated:**
- Added `CoachProfileProvider` to `MultiProvider` in `buildIntentScreen()` — required by `_buildMinimalProfile`

**Existing tests fixed:**
- `'tapping 3a chip persists intent'` → now asserts `equals('intentChip3a')` (was `contains('3a')`)
- `'tapping Autre persists intent'` → now asserts `equals('intentChipAutre')` (was `contains('Autre')`)
- `'tapping chip sets payload'` → now asserts `equals('intentChipPrevoyance')` (was `contains('prévoyance')` which would fail)

**New tests (4 + 1 = 5 added):**
1. `chip tap persists chipKey, not the localized label` — asserts `equals('intentChip3a')` + no spaces in stored value
2. `chip tap writes goalIntentTag to CapMemoryStore.declaredGoals` — taps 'projet', asserts `contains('housing_purchase')`
3. `chip tap navigates to /home?tab=0` — asserts IntentScreen gone, 'home' stub visible
4. `chip tap computes and persists premier eclairage snapshot with required keys` — asserts snapshot non-null, has value/title/suggestedRoute/colorKey/confidenceMode, lacks salary/iban

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Correctness] Added CoachProfileProvider to test widget tree**
- **Found during:** Task 2 — existing tests failed because `_buildMinimalProfile` calls `context.read<CoachProfileProvider>()`
- **Issue:** `_onChipTap` now reads CoachProfileProvider; test setup only had `CoachEntryPayloadProvider`
- **Fix:** Changed `ChangeNotifierProvider.value` to `MultiProvider` adding `CoachProfileProvider(create: (_) => CoachProfileProvider())`
- **Files modified:** `test/screens/onboarding/intent_screen_test.dart`
- **Commit:** ec64aa75

**2. [Rule 1 - Bug] Fixed existing 'prévoyance' test**
- **Found during:** Task 2 — `expect(intent, contains('prévoyance'))` would fail because `setSelectedOnboardingIntent` now stores `'intentChipPrevoyance'` (no accent)
- **Fix:** Updated assertion to `equals('intentChipPrevoyance')`
- **Files modified:** `test/screens/onboarding/intent_screen_test.dart`
- **Commit:** ec64aa75

**3. [Rule 2 - Security] use_build_context_synchronously lint**
- **Found during:** Task 1 — `_buildMinimalProfile(context)` was called after an `await`, triggering the lint
- **Fix:** Capture both `profile` (via `_buildMinimalProfile`) and `coachProfile` before any `await` in `_onChipTap`
- **Pattern:** Follows CLAUDE.md §7 "7 code safety patterns" — `context.read before await`
- **Files modified:** `apps/mobile/lib/screens/onboarding/intent_screen.dart`
- **Commit:** 6dda6ff9

## Known Stubs

None — all wiring is complete:
- `setSelectedOnboardingIntent` stores chipKey (not label) ✓
- `CapMemoryStore.declaredGoals` populated ✓
- PremierEclairage snapshot persisted ✓
- Navigation to `/home?tab=0` ✓
- The snapshot is ready for Plan 03 (PremierEclairageCard) to consume

`CapSequenceEngine.build` result is not yet consumed by any UI widget — Plan 03 will add the CapSequenceCard consumer. This is not a stub: the engine runs, the memory is updated, the consumer (CapSequenceEngine reads from CapMemory directly at render time) will use it.

## Threat Flags

None — no new network endpoints, auth paths, or schema changes. Persistence boundary remains SharedPreferences (existing trust boundary). T-03-04 (PII in snapshot) is enforced in code (explicit map construction with display-only fields) and verified in tests.

## Self-Check: PASSED

| Item | Status |
|------|--------|
| `apps/mobile/lib/screens/onboarding/intent_screen.dart` | FOUND |
| `apps/mobile/test/screens/onboarding/intent_screen_test.dart` | FOUND |
| `.planning/phases/03-onboarding-pipeline/03-02-SUMMARY.md` | FOUND |
| Commit `6dda6ff9` | FOUND |
| Commit `ec64aa75` | FOUND |
