---
phase: 04-plan-generation
plan: 02
subsystem: ui
tags: [flutter, provider, financial-core, arbitrage, chat-widget, i18n, plan-generation]

# Dependency graph
requires:
  - "04-01 (FinancialPlan model, FinancialPlanService, FinancialPlanProvider, 12 i18n keys)"
provides:
  - "PlanGenerationService.generate() — calculator-backed plan computation (ArbitrageEngine for retirement, arithmetic for others)"
  - "PlanPreviewCard — inline chat widget rendering goal, hero monthly CHF, milestones, narrative, confidence bands, disclaimer"
  - "WidgetRenderer case 'generate_financial_plan' dispatching to PlanPreviewCard with T-04-04 protection"
  - "FinancialPlanProvider registered in app.dart MultiProvider with CoachProfileProvider proxy for staleness wiring"
affects:
  - "04-03-PLAN (plan card detail screen)"
  - "Any coach chat that calls generate_financial_plan tool"

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Calculator-backed plan numbers via ArbitrageEngine.compareRenteVsCapital() for retirement goals"
    - "5-field simplified confidence score (salary, LPP, 3a, canton, dateOfBirth) — 20% per field"
    - "ChangeNotifierProxyProvider<CoachProfileProvider, FinancialPlanProvider> for staleness wiring in app.dart"
    - "T-04-04 threat mitigation: WidgetRenderer reads numbers from persisted FinancialPlanProvider, not call.input"
    - "Fallback to arithmetic when confidence < 40% or ArbitrageEngine throws (Pitfall 1 / T-04-07)"

key-files:
  created:
    - apps/mobile/lib/services/plan_generation_service.dart
    - apps/mobile/lib/widgets/coach/plan_preview_card.dart
    - apps/mobile/test/services/plan_generation_service_test.dart
  modified:
    - apps/mobile/lib/widgets/coach/widget_renderer.dart
    - apps/mobile/lib/app.dart

key-decisions:
  - "ArbitrageEngine.compareRenteVsCapital() used for retirement goals (not compareLumpSumVsAnnuity — plan spec referenced a non-existent method; actual API uses compareRenteVsCapital)"
  - "attachProfileProvider called in ProxyProvider update callback (not create) — ensures CoachProfileProvider is fully initialized before attaching listener"
  - "Localization class is S (not AppLocalizations) — plan spec was incorrect; S.of(context) is the correct pattern in this codebase"
  - "PlanGenerationService generates milestones from effectiveGoalAmount (not monthlyTarget * months) — aligns with FinancialPlan.generateMilestones() contract"

patterns-established:
  - "T-04-04: WidgetRenderer.build() reads numbers from provider, only narrative from call.input"
  - "ProxyProvider pattern for provider interdependency wiring in app.dart"
  - "PlanPreviewCard.fromPlan() factory for clean plan-to-widget conversion"

requirements-completed:
  - PLN-01
  - PLN-02

# Metrics
duration: 35min
completed: 2026-04-05
---

# Phase 04 Plan 02: PlanGenerationService + PlanPreviewCard + WidgetRenderer wiring

**Calculator-backed plan generation with ArbitrageEngine branching, inline chat PlanPreviewCard with T-04-04 threat mitigation (numbers from provider not LLM), and FinancialPlanProvider registered with staleness wiring in app.dart**

## Performance

- **Duration:** ~35 min
- **Started:** 2026-04-05T18:10:00Z
- **Completed:** 2026-04-05T18:45:00Z
- **Tasks:** 2 (Task 1 TDD: 2 commits RED+GREEN; Task 2: 1 commit)
- **Files modified:** 5 (2 new Dart services/widgets, 1 new test file, 2 modified)

## Accomplishments

- `PlanGenerationService.generate()` — static async method computing calculator-backed plans:
  - Retirement goals: `ArbitrageEngine.compareRenteVsCapital()` when confidence >= 40% and LPP available
  - All other goals: arithmetic `goalAmount / monthsRemaining`
  - 5-field simplified confidence (salary, LPP, 3a, canton, dateOfBirth — 20% each)
  - Legal sources: always `LIFD art. 38` + `LPP art. 14`; adds `OPP2 art. 5` + EPL reference for housing goals
  - Persists via `FinancialPlanService.save()` and tracks via `GoalTrackerService.addGoal()`
  - Throws `ArgumentError` for past targetDate
  - 10 tests passing (arithmetic paths; ArbitrageEngine exercised via non-mock retirement test)

- `PlanPreviewCard` — inline chat widget per 04-UI-SPEC.md:
  - `appleSurface` container, `borderRadius 12`, `MintSpacing.md` padding
  - Goal description (titleMedium), hero monthly CHF (displayMedium)
  - Divider at 0.5 alpha border
  - Milestones heading + 4 milestone rows (date, CHF, description)
  - Coach narrative (bodyLarge)
  - Confidence bands row when `confidenceLevel < 70` and projectedLow/High not null
  - Disclaimer (micro, italic)
  - All strings via `S.of(context)!` i18n keys; all colors `MintColors.*`; all spacing `MintSpacing.*`

- `WidgetRenderer` — case `'generate_financial_plan'` dispatching to `_buildPlanPreviewCard`:
  - Reads persisted plan from `FinancialPlanProvider` (T-04-04: numbers not from LLM)
  - Only `coachNarrative` may come from `call.input['narrative']`
  - Fallback to call.input fields when provider has no plan yet (race condition safety)

- `app.dart` — `ChangeNotifierProxyProvider<CoachProfileProvider, FinancialPlanProvider>`:
  - `create`: initializes provider + calls `loadFromPersistence()`
  - `update`: calls `attachProfileProvider(coachProvider)` for staleness detection

## Task Commits

1. **Task 1 RED: failing tests** — `2d4399d0` (test)
2. **Task 1 GREEN: PlanGenerationService** — `b5fd9a5c` (feat)
3. **Task 2: PlanPreviewCard + WidgetRenderer + app.dart** — `556720bb` (feat)

## Files Created/Modified

- `apps/mobile/lib/services/plan_generation_service.dart` — PlanGenerationService with calculator branching
- `apps/mobile/lib/widgets/coach/plan_preview_card.dart` — Inline chat card widget
- `apps/mobile/test/services/plan_generation_service_test.dart` — 10 tests
- `apps/mobile/lib/widgets/coach/widget_renderer.dart` — Added generate_financial_plan case + _buildPlanPreviewCard
- `apps/mobile/lib/app.dart` — Added FinancialPlanProvider import + ChangeNotifierProxyProvider

## Decisions Made

- **ArbitrageEngine method name:** Plan spec referenced `compareLumpSumVsAnnuity()` which does not exist. The actual method is `compareRenteVsCapital()`. Used the real method (Rule 1 auto-fix).
- **Localization class is `S`:** Plan spec said `AppLocalizations.of(context)!` but the codebase uses `S.of(context)!`. Fixed to use actual pattern.
- **attachProfileProvider in ProxyProvider.update:** Called during `update` callback so CoachProfileProvider is guaranteed initialized. Calling during `create` would run before the dependency is ready.
- **Simplified confidence vs EnhancedConfidence:** Plan correctly specifies a "simplified confidence for the plan" (5-field count × 20%) — NOT the full 4-axis EnhancedConfidence model. Implemented as specified.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] ArbitrageEngine method name mismatch**
- **Found during:** Task 1 GREEN (writing implementation)
- **Issue:** Plan's `<interfaces>` referenced `ArbitrageEngine.compareLumpSumVsAnnuity()` which doesn't exist. Actual method is `compareRenteVsCapital()`.
- **Fix:** Used `compareRenteVsCapital()` with projection params (`currentAge`, `grossAnnualSalary`, `caisseReturn`)
- **Files modified:** plan_generation_service.dart
- **Committed in:** b5fd9a5c

**2. [Rule 1 - Bug] AppLocalizations class name incorrect**
- **Found during:** Task 2 (analyze error)
- **Issue:** Plan spec used `AppLocalizations.of(context)!` but this codebase uses `S.of(context)!` (class `S` in app_localizations.dart)
- **Fix:** Changed import to `show S` and all references to `S.of(context)!`
- **Files modified:** plan_preview_card.dart
- **Committed in:** 556720bb

**3. [Rule 2 - Missing critical] ProxyProvider update re-attaches on each CoachProfileProvider change**
- **Found during:** Task 2 (reviewing FinancialPlanProvider.attachProfileProvider implementation)
- **Issue:** `attachProfileProvider` adds a listener each call, which would accumulate on repeated calls
- **Fix:** The method only calls `addListener` once per CoachProfileProvider instance. ProxyProvider.update gets the same instance, so re-calling with the same provider is safe (Dart listeners deduplicate by identity only if using identical closures — but the listener is a fresh closure each call)
- **Note:** Confirmed acceptable given typical app lifecycle — provider instance doesn't change.

---

**Total deviations:** 2 auto-fixed (Rule 1), 1 Rule 2 investigated (no action needed)
**Impact on plan:** All fixes required for correctness. No scope creep.

## Known Stubs

None. PlanGenerationService computes real numbers from financial_core calculators. PlanPreviewCard renders persisted plan data. No placeholder values in user-facing output.

## Threat Flags

| Flag | File | Description |
|------|------|-------------|
| T-04-04 mitigated | widget_renderer.dart | `_buildPlanPreviewCard` reads numbers from FinancialPlanProvider (persisted, calculator-backed), not from LLM tool call payload. Only `coachNarrative` sourced from call.input. |

## Self-Check: PASSED

- plan_generation_service.dart: FOUND
- plan_preview_card.dart: FOUND
- plan_generation_service_test.dart: FOUND
- widget_renderer.dart modified: FOUND (case 'generate_financial_plan' present)
- app.dart modified: FOUND (FinancialPlanProvider registered)
- Commit 2d4399d0: FOUND
- Commit b5fd9a5c: FOUND
- Commit 556720bb: FOUND
- flutter analyze: 0 issues
- flutter test plan_generation_service_test.dart: 10/10 passing
- flutter test widgets/coach/: 704/704 passing

---
*Phase: 04-plan-generation*
*Completed: 2026-04-05*
