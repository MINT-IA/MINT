---
phase: 04-plan-generation
plan: 03
subsystem: ui
tags: [flutter, provider, i18n, financial-plan, widget, animation]

# Dependency graph
requires:
  - "04-01 (FinancialPlan model, FinancialPlanProvider, 12 planCard_* i18n keys)"
  - "04-02 (FinancialPlanProvider registered in app.dart with ProxyProvider staleness wiring)"
provides:
  - "FinancialPlanCard StatefulWidget — persistent plan display on Aujourd'hui tab"
  - "MintHomeScreen Section 1b insertion — plan card between ChiffreVivant and Itineraire"
  - "Expand/collapse milestone detail via AnimatedSize + AnimatedOpacity"
  - "Stale state amber badge + Recalculer CTA wired to coach via CoachEntryPayload"
affects:
  - "Any future check-in mechanism (progress bar currently 0% — Phase 4 has no check-ins)"
  - "MintHomeScreen layout changes"

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Builder widget pattern for reactive FinancialPlanProvider watch inside SliverChildListDelegate"
    - "AnimatedSize + AnimatedOpacity combination for expand/collapse (300ms easeInOut + 200ms opacity)"
    - "SizedBox.shrink() for clean conditional section removal (not Visibility)"
    - "Swiss apostrophe grouping via replaceAll(',', '\u2019') on NumberFormat('#,##0', 'fr_CH') output"

key-files:
  created:
    - apps/mobile/lib/widgets/home/financial_plan_card.dart
  modified:
    - apps/mobile/lib/screens/main_tabs/mint_home_screen.dart

key-decisions:
  - "Used Builder widget to watch FinancialPlanProvider inside SliverChildListDelegate — avoids calling context.watch after async gaps in the StatefulWidget"
  - "onRecalculate signature changed to void Function(String recalculatePrompt) — card computes the i18n recalculate string and passes it up, rather than having MintHomeScreen know about S.of(context)!.planCard_recalculatePrompt"
  - "Used SizedBox.shrink() instead of Visibility(visible: false) per D-06 spec intent — removes section entirely from widget tree"
  - "Localization class is S (not AppLocalizations) — consistent with 04-02 finding"

patterns-established:
  - "FinancialPlanCard: pure display widget receiving plan + isStale + onRecalculate — no provider access inside the card"
  - "Section gating pattern: Builder wrapping provider watch, returns SizedBox.shrink() on false condition"

requirements-completed:
  - PLN-03
  - PLN-04

# Metrics
duration: 15min
completed: 2026-04-05
---

# Phase 04 Plan 03: FinancialPlanCard widget + MintHomeScreen integration

**StatefulWidget FinancialPlanCard with AnimatedSize expand/collapse, amber staleness badge, and Recalculer CTA wired to coach — inserted between ChiffreVivant and Itineraire on Aujourd'hui tab**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-04-05T19:00:00Z
- **Completed:** 2026-04-05T19:15:00Z
- **Tasks:** 1 auto task + 1 checkpoint (auto-approved by orchestrator)
- **Files modified:** 2 (1 new widget, 1 modified screen)

## Accomplishments

- `FinancialPlanCard` StatefulWidget (widgets/home/financial_plan_card.dart):
  - Container with `MintColors.white`, borderRadius 16, 0.5-alpha border
  - Goal prefix + description row (titleMedium), stale amber badge (_StaleBadge) when `isStale`
  - Hero monthly CHF in displayMedium with Swiss apostrophe grouping (`\u2019`)
  - Target date (bodyMedium, textMuted), progress bar (6px, 0%, success color)
  - Caption row: `0 % atteint` + CTA button (_CtaButton)
  - CTA toggles "Voir le détail" / "Masquer le détail" (normal) or "Recalculer" (stale)
  - AnimatedSize (300ms easeInOut) + AnimatedOpacity (200ms) expand/collapse detail
  - Expanded detail: milestones heading, 4 milestone rows (date/description/CHF), confidence bands, disclaimer
  - All strings `S.of(context)!.*`, all colors `MintColors.*`, all spacing `MintSpacing.*`

- `MintHomeScreen` updated:
  - Imports `financial_plan_provider.dart` + `financial_plan_card.dart`
  - `Builder` wrapping `context.watch<FinancialPlanProvider>()` inserted between Section 1 and Section 2
  - Hidden entirely (`SizedBox.shrink()`) when `!planProvider.hasPlan`
  - `onRecalculate` wired to `widget.onSwitchToCoach` with `CoachEntryPayload(source: homeChip, topic: recalculatePlan, userMessage: prompt)` — user must tap Send in coach (T-04-10 mitigation)

- `flutter analyze --no-fatal-infos`: 0 issues

## Task Commits

1. **Task 1: FinancialPlanCard + MintHomeScreen integration** — `dd8b313a` (feat)
2. **Task 2: Visual verification checkpoint** — auto-approved by orchestrator

## Files Created/Modified

- `apps/mobile/lib/widgets/home/financial_plan_card.dart` — FinancialPlanCard StatefulWidget with sub-widgets (_StaleBadge, _CtaButton, _ExpandedDetail, _MilestoneRow)
- `apps/mobile/lib/screens/main_tabs/mint_home_screen.dart` — Added imports + Section 1b Builder insertion

## Decisions Made

- **Builder for provider watch:** Used `Builder` widget inside `SliverChildListDelegate` to safely call `context.watch<FinancialPlanProvider>()` — the enclosing `_MintHomeScreenState.build()` already uses `context.watch<MintStateProvider>()`, and nesting another watch in the same context would be fine, but Builder provides clear scope separation.
- **onRecalculate passes the prompt string up:** The card itself has the i18n context to build the recalculate prompt, so it computes `S.of(context)!.planCard_recalculatePrompt(plan.goalDescription)` and passes the string to the callback. MintHomeScreen just wraps it in `CoachEntryPayload.userMessage`. Clean separation of concerns.
- **S not AppLocalizations:** Confirmed from 04-02 that the localization class in this codebase is `S` (imported from `app_localizations.dart`).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] onRecalculate callback signature clarified**
- **Found during:** Task 1 (reading plan specification)
- **Issue:** Plan spec says `onRecalculate: () { // Use CoachEntryPayloadProvider or onSwitchToCoach }` but the card needs to pass the i18n prompt string up to the caller. Plan interface was `VoidCallback` but the card must compute the prompt inside widget (has l10n context).
- **Fix:** Changed signature to `void Function(String recalculatePrompt)` — card builds the prompt from `S.of(context)!.planCard_recalculatePrompt(plan.goalDescription)` and passes it up. MintHomeScreen wraps in `CoachEntryPayload(userMessage: recalculatePrompt)`.
- **Files modified:** financial_plan_card.dart, mint_home_screen.dart
- **Verification:** flutter analyze 0 issues, all acceptance criteria pass
- **Committed in:** dd8b313a

---

**Total deviations:** 1 auto-fixed (Rule 1 — interface clarification)
**Impact on plan:** Clean fix enabling i18n prompt construction inside the widget where context is available.

## Issues Encountered

None.

## Known Stubs

One intentional stub:
- `financial_plan_card.dart` line ~113: `LinearProgressIndicator(value: 0.0)` — progress bar hardcoded to 0% because Phase 4 has no check-in mechanism. The `planCard_progressCaption` displays "0 % atteint". This is intentional per plan spec: "value 0.0 (Phase 4 has no check-ins)". A future plan implementing check-ins will wire the actual progress value here.

## Threat Flags

None. T-04-10 (recalculate prompt injection) is mitigated: prompt is pre-formatted via `planCard_recalculatePrompt` i18n key with goalDescription interpolation, passed as `CoachEntryPayload.userMessage` — user must explicitly tap Send.

## Next Phase Readiness

- Complete plan generation pipeline is now wired end-to-end:
  - Chat: PlanPreviewCard inline in coach (04-02)
  - Persistent: FinancialPlanCard on Aujourd'hui tab (04-03)
  - Staleness: amber badge when CoachProfile changes (04-01 + 04-03)
  - Recalculate: opens coach with pre-seeded prompt (04-03)
- Phase 04 requirements PLN-01 through PLN-04 are complete
- Future check-in mechanism can wire progress bar value (currently 0%)

## Self-Check: PASSED

- financial_plan_card.dart: FOUND
- mint_home_screen.dart modified (FinancialPlanCard + FinancialPlanProvider): FOUND
- Commit dd8b313a: FOUND
- flutter analyze 0 issues: CONFIRMED
- All 10 acceptance criteria: PASS

---
*Phase: 04-plan-generation*
*Completed: 2026-04-05*
