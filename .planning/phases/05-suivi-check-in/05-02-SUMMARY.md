---
phase: 05-suivi-check-in
plan: 02
subsystem: coach-ui
tags: [check-in, widget-renderer, plan-reality, streak, memory, notification-routing, i18n]
dependency_graph:
  requires: [05-01]
  provides: [SUI-02, SUI-03, SUI-04, SUI-05]
  affects:
    - apps/mobile/lib/widgets/coach/widget_renderer.dart
    - apps/mobile/lib/screens/main_tabs/mint_home_screen.dart
    - apps/mobile/lib/screens/main_navigation_shell.dart
    - apps/mobile/lib/services/coach/context_injector_service.dart
tech_stack:
  added: []
  patterns:
    - WidgetRenderer switch dispatch for record_check_in tool
    - ConversationMemoryService static builder pattern for LLM context blocks
    - ContextInjectorService checkIn block appended to system prompt
    - PlanRealityCard optional streakBadge as full-width child below header
    - AnimatedSwitcher wrapping PlanRealityCard on MintHomeScreen
    - MainNavigationShell intent parsing via Uri.queryParameters
key_files:
  created:
    - apps/mobile/lib/widgets/coach/check_in_summary_card.dart
    - apps/mobile/lib/widgets/coach/first_check_in_cta_card.dart
    - apps/mobile/test/services/conversation_memory_test.dart
    - apps/mobile/test/widgets/check_in_tool_test.dart
    - apps/mobile/test/widgets/plan_reality_home_test.dart
  modified:
    - apps/mobile/lib/widgets/coach/widget_renderer.dart
    - apps/mobile/lib/widgets/coach/plan_reality_card.dart
    - apps/mobile/lib/services/coach/conversation_memory_service.dart
    - apps/mobile/lib/services/coach/context_injector_service.dart
    - apps/mobile/lib/screens/main_tabs/mint_home_screen.dart
    - apps/mobile/lib/screens/main_navigation_shell.dart
    - apps/mobile/lib/l10n/app_fr.arb (+ 5 other ARB files)
decisions:
  - "StreakBadgeWidget placed below PlanRealityCard header (not inside header Row) — StreakBadgeWidget uses Expanded internally and cannot be placed in an unbounded horizontal Row"
  - "ConversationMemoryService.buildCheckInSummary() outputs total CHF only (T-05-06 PII minimization — no contribution_id keys in LLM context)"
  - "MainNavigationShell._handlePendingRoute() only dispatches known intent values (T-05-07 tampering mitigation)"
  - "WidgetRenderer._buildCheckInSummaryCard() validates all fields before creating MonthlyCheckIn (T-05-04 tampering mitigation)"
metrics:
  duration: "~4 hours (cross-session)"
  completed_date: "2026-04-05"
  tasks_completed: 2
  files_changed: 14
---

# Phase 05 Plan 02: Check-in UI Wiring + Coach Memory Summary

Wire record_check_in tool dispatch via WidgetRenderer to CheckInSummaryCard + CoachProfile persistence, enrich LLM system prompt with last check-in amount via ConversationMemoryService, add FirstCheckInCtaCard empty state and PlanRealityCard integration on MintHomeScreen, and route notification intent=monthlyCheckIn to coach tab.

## What Was Built

### Task 1: record_check_in tool dispatch + ConversationMemory enrichment

**WidgetRenderer** (`widget_renderer.dart`): added `case 'record_check_in'` that calls `_buildCheckInSummaryCard()`. The private method validates `month`, `versements`, and `summary_message` fields, rejects non-numeric versements values (T-05-04), creates a `MonthlyCheckIn` via `context.read<CoachProfileProvider>().addCheckIn()`, and returns a `CheckInSummaryCard`.

**CheckInSummaryCard** (`check_in_summary_card.dart`): inline chat card with `MintColors.appleSurface` background showing the LLM's summary message, itemized versements breakdown, and total CHF formatted via `formatChf()`.

**ConversationMemoryService** (`conversation_memory_service.dart`): added `buildCheckInSummary(CoachProfile)` static method. Returns the most recent check-in's total CHF (rounded) as a one-line French string. No contribution IDs exposed (T-05-06). Returns empty string if no check-ins exist.

**ContextInjectorService** (`context_injector_service.dart`): calls `ConversationMemoryService.buildCheckInSummary(profile)` before assembling system prompt, passes result as `checkInBlock` to `_buildMemoryBlock()`, which appends it after the budget block when non-empty.

**13 i18n keys** added to all 6 ARB files: `firstCheckInCardTitle`, `firstCheckInCardBody`, `checkInCtaButton`, `checkInCoachOpener`, `checkInCoachFollowUp`, `checkInCoachMemory`, `checkInCoachSummary`, `checkInErrorNoPlan`, `checkInErrorSaveFailed`, `adherenceBadgeOnTrack`, `adherenceBadgeProgress`, `adherenceBadgeOffTrack`, `checkInTotalLabel`.

### Task 2: UI Integration — PlanRealityCard + FirstCheckInCtaCard + notification routing

**PlanRealityCard** (`plan_reality_card.dart`): added `final Widget? streakBadge` parameter. Rendered as a full-width child below the header row (not inside the header Row — see deviation below). Made `compoundImpact` nullable with null-safe guard.

**FirstCheckInCtaCard** (`first_check_in_cta_card.dart`): new empty-state card using `MintSurface(tone: MintSurfaceTone.craie)`, `Icons.calendar_today_outlined` icon, i18n strings for title/body/CTA, and a `FilledButton` with `onTap` callback.

**MintHomeScreen Section 1c** (`mint_home_screen.dart`): `Builder` watching `CoachProfileProvider` and `FinancialPlanProvider`. Shows `FirstCheckInCtaCard` when no check-ins and `hasPlan=true`. Shows `PlanRealityCard` with `streakBadge: StreakBadgeWidget(streak: streak)` and `AnimatedSwitcher(duration: 300ms)` when check-ins and contributions exist. Hidden entirely when no plan and no data.

**MainNavigationShell** (`main_navigation_shell.dart`): `_handlePendingRoute(String)` method replaces the raw `GoRouter.of(context).go()` call at both consumption points (initState cold start and `didChangeAppLifecycleState` resume). Parses `?intent=monthlyCheckIn` from the pending route URI and calls `_switchToCoachWithPayload(CoachEntryPayload(source: CoachEntrySource.notification, topic: 'monthlyCheckIn'))` instead. Unknown routes fall through to `GoRouter.go()` unchanged.

## Tests

| File | Tests | Coverage |
|------|-------|----------|
| `test/services/conversation_memory_test.dart` | 7 | empty checkIns, single, most-recent selection, rounding, multi-versement sum, month names, T-05-06 no contribution_id |
| `test/widgets/check_in_tool_test.dart` | 6 | valid input renders+persists, missing month/versements/summary_message return null, T-05-04 non-numeric versements, card displays content |
| `test/widgets/plan_reality_home_test.dart` | 4 | hasPlan+no-checkIn shows CTA, no-plan+no-checkIn shows nothing, checkIns+contributions shows PlanRealityCard, StreakBadgeWidget is descendant of PlanRealityCard |

All 17 tests pass. `flutter analyze` reports 0 issues on all modified files.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] StreakBadgeWidget placed below header, not inside header Row**
- **Found during:** Task 2 test execution
- **Issue:** `StreakBadgeWidget` has an `Expanded` child inside its root `Row`. Placing it inside `PlanRealityCard`'s header `Row(mainAxisSize: MainAxisSize.min)` produces unbounded width constraints — `RenderFlex children have non-zero flex but incoming width constraints are unbounded`.
- **Fix:** Moved `streakBadge` rendering from inside the inner badge Row to a full-width position directly below the header Row (separated by 12px gap). This preserves the "inside PlanRealityCard" requirement (StreakBadgeWidget is still a descendant of PlanRealityCard) while respecting the widget's layout contract.
- **Files modified:** `apps/mobile/lib/widgets/coach/plan_reality_card.dart`
- **Commit:** `a5e2e77c`

**2. [Rule 1 - Bug] FinancialPlanProvider has no loadPlan() method**
- **Found during:** Task 2 test writing
- **Issue:** Plan's test spec referenced `planProvider.loadPlan({'title': ..., 'actions': []})` but `FinancialPlanProvider` has no such method. The test-visible method is `setPlanDirect(FinancialPlan)` (annotated `@visibleForTesting`).
- **Fix:** Test uses `setPlanDirect()` with a properly constructed `FinancialPlan` object.
- **Files modified:** `apps/mobile/test/widgets/plan_reality_home_test.dart`
- **Commit:** `a5e2e77c`

**3. [Rule 3 - Blocking] plan_reality_home_test.dart import at bottom of file**
- **Found during:** Task 2 test file hand-off from previous session
- **Issue:** The file created in the previous session had `import 'package:mint_mobile/services/streak_service.dart';` placed after all class definitions — invalid Dart syntax that fails compilation. Also had recursive `from()` method structure.
- **Fix:** Rewrote the file with all imports at top and simplified test structure using inline `sectionBuilder` lambdas.
- **Files modified:** `apps/mobile/test/widgets/plan_reality_home_test.dart`
- **Commit:** `a5e2e77c`

## Commits

| Hash | Task | Description |
|------|------|-------------|
| `3437e15d` | Task 1 | WidgetRenderer record_check_in dispatch + CheckInSummaryCard + ConversationMemory enrichment |
| `a5e2e77c` | Task 2 | PlanRealityCard streakBadge + FirstCheckInCtaCard + home integration + notification routing |

## Known Stubs

None. All wiring is live:
- `record_check_in` tool call persists to `CoachProfileProvider` and renders `CheckInSummaryCard`
- `ConversationMemoryService.buildCheckInSummary()` reads real `CoachProfile.checkIns`
- `ContextInjectorService` appends real check-in block to LLM system prompt
- `MintHomeScreen` Section 1c reads live `CoachProfileProvider` and `FinancialPlanProvider`
- `MainNavigationShell` routes real notification intents to coach tab

## Threat Surface Scan

No new network endpoints, auth paths, or file access patterns introduced. All changes are within existing UI/service layer. T-05-04, T-05-06, T-05-07 mitigations confirmed implemented per plan threat model.

## Self-Check: PASSED

All files verified present. All commits verified in git history.

| Check | Result |
|-------|--------|
| `check_in_summary_card.dart` | FOUND |
| `first_check_in_cta_card.dart` | FOUND |
| `plan_reality_home_test.dart` | FOUND |
| `check_in_tool_test.dart` | FOUND |
| `conversation_memory_test.dart` | FOUND |
| commit `3437e15d` | FOUND |
| commit `a5e2e77c` | FOUND |
