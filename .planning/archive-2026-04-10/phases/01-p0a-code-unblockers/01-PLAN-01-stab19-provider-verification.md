---
phase: 01-p0a-code-unblockers
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - apps/mobile/test/smoke/mint_home_smoke_test.dart
autonomous: true
requirements: [STAB-19]
must_haves:
  truths:
    - "mint_home_screen.dart renders inside the real MultiProvider shell without ProviderNotFoundException"
    - "flutter analyze lib/ reports 0 errors"
    - "grep gate confirms no ProviderNotFoundException reference in mint_home_screen.dart"
  artifacts:
    - path: apps/mobile/test/smoke/mint_home_smoke_test.dart
      provides: "Widget smoke test pumping MintHomeScreen inside app MultiProvider"
  key_links:
    - from: apps/mobile/test/smoke/mint_home_smoke_test.dart
      to: apps/mobile/lib/app.dart
      via: "reuses app MultiProvider shell"
      pattern: "MultiProvider"
---

<objective>
Verify STAB-19 per D-01 (CONTEXT.md): the 4 providers (`MintStateProvider`, `FinancialPlanProvider`, `CoachEntryPayloadProvider`, `OnboardingProvider`) are already registered in `apps/mobile/lib/app.dart:1010-1013`. This plan collapses STAB-19 to verification-only — no rewire.

Purpose: Prove the carryover bug is closed before Phase 2 contracts work begins.
Output: Passing widget smoke test + green grep gate + 0-error analyze.
</objective>

<context>
@.planning/phases/01-p0a-code-unblockers/01-CONTEXT.md
@.planning/ROADMAP.md
@.planning/REQUIREMENTS.md
@apps/mobile/lib/app.dart
@apps/mobile/lib/screens/main_tabs/mint_home_screen.dart
</context>

<tasks>

<task type="auto">
  <name>Task 1: Verify provider registration + create smoke test (STAB-19 per D-01)</name>
  <files>apps/mobile/test/smoke/mint_home_smoke_test.dart</files>
  <action>
Per D-01 CONTEXT.md:

1. Read `apps/mobile/lib/app.dart` lines 971-1013 and confirm the 4 providers are present in the MultiProvider:
   - `MintStateProvider`
   - `FinancialPlanProvider`
   - `CoachEntryPayloadProvider`
   - `OnboardingProvider`
   If any are missing, STOP and report — D-01 assumes they exist; if not, escalate (do not silently add).

2. Create `apps/mobile/test/smoke/mint_home_smoke_test.dart` that:
   - Imports the real `MultiProvider` shell from `app.dart` (or reconstructs it with the same 4 providers using their zero-arg / default constructors).
   - Pumps `MintHomeScreen` inside the shell via `tester.pumpWidget(...)`.
   - Uses `await tester.pumpAndSettle(const Duration(milliseconds: 500))`.
   - Asserts `tester.takeException()` is null (catches any `ProviderNotFoundException`).
   - Reuses existing smoke test patterns from `apps/mobile/test/` (grep for existing `pumpWidget.*MultiProvider` examples first).
   - Wording of the test is Claude's discretion per D-01 §Claude's Discretion.
   - Avoid mocking the providers — the test's whole point is to exercise the real shell.

3. Run acceptance commands below and confirm all green before committing.
  </action>
  <verify>
    <automated>cd apps/mobile &amp;&amp; flutter analyze lib/ test/smoke/mint_home_smoke_test.dart &amp;&amp; flutter test test/smoke/mint_home_smoke_test.dart &amp;&amp; cd ../.. &amp;&amp; git grep -n 'ProviderNotFoundException' apps/mobile/lib/screens/main_tabs/mint_home_screen.dart; test $? -eq 1</automated>
  </verify>
  <done>
- `flutter analyze lib/` = 0 errors
- `flutter test test/smoke/mint_home_smoke_test.dart` = green
- `git grep 'ProviderNotFoundException' apps/mobile/lib/screens/main_tabs/mint_home_screen.dart` returns nothing (exit code 1)
- Smoke test file committed
  </done>
</task>

</tasks>

<verification>
All three gates from D-01 green:
1. `git grep ProviderNotFoundException apps/mobile/lib/screens/main_tabs/mint_home_screen.dart` → 0 hits
2. `flutter analyze lib/` → 0 errors
3. `flutter test test/smoke/mint_home_smoke_test.dart` → green
</verification>

<success_criteria>
STAB-19 closed per ROADMAP Phase 1 success criterion #2. No rewire was needed; the providers were already registered.
</success_criteria>

<rollback>
Single commit → `git revert HEAD` removes the smoke test file. No production code touched.
</rollback>

<output>
After completion, create `.planning/phases/01-p0a-code-unblockers/01-01-SUMMARY.md` documenting:
- Confirmation of the 4 provider registrations (line numbers in app.dart)
- Smoke test location + what it asserts
- All 3 gate commands + their outputs
</output>
