---
phase: mint-illogism-fixes
plan: 08
subsystem: ui
tags: [fatca, archetype, gorouter, redirect, pillar3a, cross-border, financial_core, tdd]

# Dependency graph
requires:
  - phase: mint-illogism-fixes-06
    provides: usTaxPerson onboarding question + expatUs archetype detection
  - phase: mint-illogism-fixes-07
    provides: ArchetypePredicates shared-predicate pattern (financial_core L1)
provides:
  - Global FATCA archetype gate in the GoRouter redirect (every prévoyance surface)
  - archetypeRedirectTarget pure helper (router/archetype_route_gate.dart)
  - MinimalProfileService.compute() archetype-aware (canContribute3a param)
  - ArchetypePredicates.canContribute3a single source of truth (3a deduction right)
  - coach_profile.canContribute3a gated on quasi-résident status (no more cross-path divergence)
affects: [premier_eclairage, response_card, onboarding, coach-gate, fatca-compliance]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Pure redirect-decision helper extracted from GoRouter redirect for unit-testability"
    - "Single archetype predicate (ArchetypePredicates) consumed by both profile engines (NEVER #3)"

key-files:
  created:
    - apps/mobile/lib/router/archetype_route_gate.dart
    - apps/mobile/test/screens/fatca_gate_test.dart
  modified:
    - apps/mobile/lib/app.dart
    - apps/mobile/lib/models/coach_profile.dart
    - apps/mobile/lib/services/minimal_profile_service.dart
    - apps/mobile/lib/services/financial_core/archetype_predicates.dart
    - apps/mobile/lib/providers/coach_profile_provider.dart
    - apps/mobile/test/services/financial_parity_test.dart

key-decisions:
  - "FATCA gate placed in the authenticated-scope branch of the existing redirect — automatically covers /home, /mon-argent, /profile/bilan, /explore/*, /coach/* without per-route wiring"
  - "Quasi-résident eligibility = work canton == 'GE' (same predicate as segments_service._add3aRules) — no new model field invented"
  - "Global gate fires only for hydrated + positively-identified archetypes (never unknown/null) to avoid flash-blocking legitimate non-US users at boot"

patterns-established:
  - "Pattern: archetype redirect decision is a pure function testable without a MaterialApp.router pump"
  - "Pattern: 3a deduction right is one predicate (ArchetypePredicates.canContribute3a) shared across calc + model"

requirements-completed: [MATRIX-expat_us-1, MATRIX-expat_us-2, MATRIX-frontalier-1]

# Metrics
duration: ~35min
completed: 2026-06-11
---

# Phase mint-illogism-fixes Plan 08: W2 — Gates 3a/FATCA Summary

**FATCA gate promoted from coach-only point-defense to a GLOBAL GoRouter redirect, and the 3a calc layer made archetype-aware so a US person or non-quasi-résident frontalier never sees an actionable 7258 CHF plafond.**

## Performance

- **Duration:** ~35 min
- **Completed:** 2026-06-11T16:26:29Z
- **Tasks:** 2 (both TDD: RED → GREEN)
- **Files modified:** 8 (2 created, 6 modified)

## Accomplishments
- **expat_us-1 closed:** an `expatUs` profile reaching any prévoyance surface (`/home`, `/mon-argent`, `/profile/bilan`, `/explore/*`, `/coach/*`) is now redirected to `/waitlist` by the global redirect — the coach-entry point-defense gate is kept (defense in depth, T-ILF-08-01).
- **expat_us-2 closed:** `MinimalProfileService.compute()` is archetype-aware; for a US person `plafond3a`, `taxSaving3a` and `marginalTaxRate` are all 0 — the FATCA-blind 7258 forfait is gone from the calc layer.
- **frontalier-1 closed:** `coach_profile.canContribute3a` now gates the cross-border deduction on quasi-résident status (work canton GE), aligned with the `segments_service` hub; a frontalier hors-GE no longer sees a deductible 3a plafond on the generic path.
- **Single source of truth:** `ArchetypePredicates.canContribute3a` is consumed by BOTH profile engines (calc + model), ending the cross-path divergence (CLAUDE.md NEVER #3).

## Task Commits

Each task was committed atomically (TDD test → feat):

1. **Task 1 (RED): failing global FATCA gate test** — `e52c598a9` (test)
2. **Task 1 (GREEN): global FATCA gate in GoRouter redirect** — `a931b6a0a` (feat)
3. **Task 2 (RED): failing 3a eligibility parity** — `3443bda83` (test)
4. **Task 2 (GREEN): archetype-aware compute() + quasi-résident 3a** — `eeffec4ae` (feat)

## Files Created/Modified
- `apps/mobile/lib/router/archetype_route_gate.dart` — NEW pure helper `archetypeRedirectTarget`; reuses `evaluateCoachArchetypeGate` + `enableCoachHardGate`; gate-exempt prefix allowlist for correction/public surfaces.
- `apps/mobile/lib/app.dart` — authenticated-scope branch of the redirect now calls the helper (reads `CoachProfileProvider.profile`).
- `apps/mobile/lib/services/financial_core/archetype_predicates.dart` — NEW `canContribute3a` predicate (US → false; cross-border deductible only if GE quasi-résident with income; else fallback).
- `apps/mobile/lib/services/minimal_profile_service.dart` — `compute()` gains `bool canContribute3a = true`; false → 3a outputs forced to 0.
- `apps/mobile/lib/models/coach_profile.dart` — `canContribute3a` getter delegates to the shared predicate (replaces the unconditional `isCrossBorder && revenu>0 → true`).
- `apps/mobile/lib/providers/coach_profile_provider.dart` — single `compute()` caller wires the boolean from the same predicate.
- `apps/mobile/test/screens/fatca_gate_test.dart` — NEW 7-case suite for the global gate.
- `apps/mobile/test/services/financial_parity_test.dart` — NEW W6 group (6 cases) for 3a eligibility.

## Decisions Made
- **Gate placement:** placed in the `authenticated` scope branch rather than per-route. The existing `ScopedGoRoute` scope mechanism already classifies prévoyance surfaces as `authenticated` and correction surfaces (`/onb`, `/scan`, `/settings`, `/auth`, `/anonymous`, `/waitlist`) as `public`/`onboarding`, so the gate auto-covers the right set without duplicating a route whitelist.
- **Quasi-résident signal:** the model has no dedicated quasi-résident boolean; the reference gate (`segments_service._add3aRules`) uses `cantonTravail == 'GE'` as the eligibility proxy (LIPP GE art. 6 al. 1). The shared predicate uses the same `workCanton == 'GE'` criterion — faithful to the existing hub, no new field invented (Karpathy #2 simplicity).
- **Boot safety:** the global gate fires only when the profile is hydrated AND the archetype is a positive (non-`unknown`) signal, so a not-yet-hydrated profile never flash-blocks a legitimate non-US user (plan must-have explicitly required this; narrower than the coach gate which also blocks `unknown`).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Added explicit `archetype_predicates.dart` import to coach_profile_provider.dart**
- **Found during:** Task 2 (wiring the single `compute()` caller)
- **Issue:** `ArchetypePredicates` was undefined in the provider — `minimal_profile_service.dart` imports `financial_core.dart` but does not re-export it, so the symbol was not transitively visible.
- **Fix:** Added `import 'package:mint_mobile/services/financial_core/archetype_predicates.dart';` to the provider.
- **Files modified:** apps/mobile/lib/providers/coach_profile_provider.dart
- **Verification:** `flutter analyze` → "No issues found".
- **Committed in:** `eeffec4ae` (Task 2 GREEN commit)

---

**Total deviations:** 1 auto-fixed (1 blocking import).
**Impact on plan:** Trivial — a missing import surfaced by the analyzer. No scope creep.

## Issues Encountered
None beyond the import above. The plan's line-number references were slightly stale (codebase had drifted since planning), so the actual sites were re-located by grep before editing (`canContribute3a` getter at coach_profile.dart:2106; `compute()` 3a section at minimal_profile_service.dart:165-203).

## Verification

- `flutter test test/screens/fatca_gate_test.dart` → **7/7 passed** (exit 0).
- `flutter test test/services/financial_parity_test.dart` → **39/39 passed** (33 prior + 6 new W6, exit 0).
- `flutter test` (full mobile suite) → **+9368 ~24, All tests passed** (0 failures).
- `flutter analyze` (full `mobile`) → **No issues found**.
- Oracle expat_us-1 grep: `grep -n "archetypeRedirectTarget" apps/mobile/lib/app.dart` → present in the authenticated-scope redirect branch.
- Acceptance grep `MinimalProfileService.compute` callers in `lib/`: **1 production caller**, updated (other two hits are comments).

## Known Stubs
None. No hardcoded empty values flowing to UI; the 3a-zeroing for gated archetypes is the intended suppression, not a stub.

## TDD Gate Compliance
Both tasks followed RED → GREEN. RED commits (`e52c598a9`, `3443bda83`) document failing states (compile error on missing symbol — the canonical RED for a not-yet-implemented API), GREEN commits (`a931b6a0a`, `eeffec4ae`) make them pass. No REFACTOR needed.

## Deferred Items (for orchestrator)
- **W2 device-proof sim walkthrough** (Task 2 acceptance criterion + must-have truth #4): captures under `.planning/_walker/illogism-fixes/w2/` proving (a) US person gated to /waitlist from /mon-argent, (b) frontalier without deductible 3a. This requires the iOS simulator + Maestro, which is not runnable from the parallel worktree executor (build constraint — same deferral pattern as plan 05). **The orchestrator owns the device-proof gate.** Unit + integration evidence is green and cited above; end-to-end sim verification is UNKNOWN until the orchestrator runs the W2 walker.

## Next Phase Readiness
- W2 (10 ILLOGICAL_FOR_ARCHETYPE) is fully addressed at the code+test layer by plans 06-08. The remaining gate is the W2 device-proof, deferred to the orchestrator.
- The `archetypeRedirectTarget` helper + `fatca_gate_test.dart` form a permanent regression harness for future routes (T-ILF-08-03 mitigation).

## Self-Check: PASSED
- All 9 declared files exist on disk (2 created, 6 modified, 1 SUMMARY).
- All 4 task commits exist in git log (`e52c598a9`, `a931b6a0a`, `3443bda83`, `eeffec4ae`).

---
*Phase: mint-illogism-fixes*
*Completed: 2026-06-11*
