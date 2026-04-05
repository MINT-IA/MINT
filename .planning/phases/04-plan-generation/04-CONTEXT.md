# Phase 4: Plan Generation - Context

**Gathered:** 2026-04-05
**Status:** Ready for planning
**Mode:** Auto-generated (autonomous smart discuss)

<domain>
## Phase Boundary

The coach generates a persistent, chiffered financial plan from the user's declared goal — visible outside chat history and adaptive to profile changes.

Key builds:
1. A `FinancialPlan` model with monthly target, milestones, timeline, and coach narrative
2. A `generate_financial_plan` coach tool that produces structured plan output
3. Plan persistence (SharedPreferences) and a `FinancialPlanProvider` for reactivity
4. A `FinancialPlanCard` on MintHomeScreen (between Section 1 and Section 3)
5. Plan invalidation when CoachProfile changes (salary, etc.)

</domain>

<decisions>
## Implementation Decisions

### D-01: FinancialPlan Model
Create `lib/models/financial_plan.dart` with: `id`, `goalDescription`, `goalCategory` (from GoalTemplate enum), `monthlyTarget` (CHF), `milestones` (List of dated intermediate targets), `projectedOutcome` (CHF at target date), `targetDate`, `generatedAt`, `profileHashAtGeneration`, `coachNarrative` (human-readable explanation), `confidenceLevel`, `sources` (legal refs). JSON serializable for SharedPreferences.

### D-02: generate_financial_plan Tool
Add a new tool name `GENERATE_FINANCIAL_PLAN` to the coach tool calling system. The LLM produces a JSON payload with: `goal`, `monthly_amount`, `milestones` (array of {date, target, description}), `projected_outcome`, `narrative`. `ChatToolDispatcher` normalizes it. `WidgetRenderer` displays an inline `PlanPreviewCard` in chat. The plan is simultaneously persisted.

### D-03: Plan Computation Approach
The plan numbers come from EXISTING calculators (not the LLM):
- Monthly savings target → derived from goal amount ÷ months remaining, adjusted by `ArbitrageEngine.compareLumpSumVsAnnuity` for retirement goals
- Milestones → quarterly checkpoints (25%/50%/75%/100% of target)
- Projected outcome → `MonteCarloService.runSimulation()` for confidence bands (low/mid/high)
The LLM provides the narrative framing and goal extraction; the numbers are calculator-backed.

### D-04: Plan Persistence
Store in SharedPreferences under key `financial_plan_v1` as JSON. Use `SecureWizardStore` pattern if plan contains sensitive amounts. Max 3 active plans (oldest auto-archived). `FinancialPlanService` handles CRUD.

### D-05: FinancialPlanProvider
A `ChangeNotifier` provider that:
- Loads plan from persistence on init
- Exposes `currentPlan`, `hasPlan`, `isPlanStale`
- Listens to `CoachProfileProvider` — when salary/savings change, marks plan as stale via `profileHashAtGeneration` comparison
- Stale plan shows a "recalculer" prompt, doesn't auto-regenerate (user must confirm)

### D-06: FinancialPlanCard on MintHomeScreen
Add as a conditional section after ChiffreVivantCard (Section 1). Shows:
- Goal description + target date
- Monthly target amount (prominent number)
- Progress bar (0% initially, fills as check-ins accumulate)
- "Voir le détail" CTA → expands inline or navigates to a dedicated plan detail screen
- If plan is stale: amber badge "Profil modifié — recalculer"
- If no plan: section hidden (not an empty state card)

### D-07: Plan Generation Flow
1. User tells coach their goal ("j'veux acheter un appart dans 3 ans")
2. Coach extracts goal via LLM → calls `GENERATE_FINANCIAL_PLAN` tool
3. `PlanGenerationService.generate(goalDescription, targetDate, profile)` computes numbers from financial_core calculators
4. Plan persisted + displayed as inline PlanPreviewCard in chat
5. Plan also accessible from MintHomeScreen FinancialPlanCard

### D-08: Plan-Profile Linkage
`profileHashAtGeneration` = hash of (salary, lppAvoir, 3aCapital, canton, birthDate). When any of these change in CoachProfile, the hash mismatches → plan marked stale. Monthly amount recalculation is a lightweight operation (no Monte Carlo needed for simple recompute).

### D-09: Integration with Existing Systems
- `UserGoal` from `GoalTrackerService` — when a plan is generated, also create/update a `UserGoal` entry for coach context continuity
- `PlannedMonthlyContribution` — when a plan is accepted, optionally add it to the wizard's `plannedContributions` list for suivi integration
- `CapSequenceEngine` — plan generation triggers CapMemory update (goal declared)

### Claude's Discretion
- Exact LLM prompt for goal extraction and narrative generation
- Whether the plan detail view is a new screen or an expandable section
- Animation style for PlanPreviewCard in chat
- Whether to show Monte Carlo confidence bands or simplified low/mid/high
- Milestone naming conventions

</decisions>

<canonical_refs>
## Canonical References

### Financial Core
- `apps/mobile/lib/services/financial_core/arbitrage_engine.dart` — lump sum vs annuity comparison
- `apps/mobile/lib/services/financial_core/monte_carlo_service.dart` — stochastic projections
- `apps/mobile/lib/services/financial_core/tax_calculator.dart` — tax implications

### Coach System
- `apps/mobile/lib/services/coach/tool_call_parser.dart` — tool name registration
- `apps/mobile/lib/services/coach/chat_tool_dispatcher.dart` — normalize pipeline
- `apps/mobile/lib/widgets/coach/widget_renderer.dart` — render switch

### Existing Plan Infrastructure
- `apps/mobile/lib/models/coach_profile.dart` — PlannedMonthlyContribution, MonthlyCheckIn
- `apps/mobile/lib/services/plan_tracking_service.dart` — adherence score, gap CHF
- `apps/mobile/lib/services/coach/goal_tracker_service.dart` — UserGoal persistence

### Home Screen
- `apps/mobile/lib/screens/main_tabs/mint_home_screen.dart` — Section insertion point

### Persistence
- `apps/mobile/lib/services/report_persistence_service.dart` — SharedPreferences patterns

</canonical_refs>

<specifics>
## Specific Ideas

- Numbers must be calculator-backed, not LLM-hallucinated. LLM extracts the goal; `PlanGenerationService` computes the numbers.
- Plan must include legal disclaimer and sources (LIFD art. references for tax implications).
- The "monthly savings target" is the hero number — it answers "que dois-je faire concrètement?"
- Milestones use quarterly intervals for simplicity (not custom dates).

</specifics>

<deferred>
## Deferred Ideas

- Plan sharing/export as PDF → Phase 8 or later
- Multiple concurrent plans → v2 (max 3 for now, but UI shows only the active one)
- Plan comparison ("what if I save 500 more per month?") → Phase 5 check-in context

</deferred>

---

*Phase: 04-plan-generation*
*Context gathered: 2026-04-05 via autonomous smart discuss*
