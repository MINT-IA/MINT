# Phase 7: Life Event Journeys - Context

**Gathered:** 2026-04-06
**Status:** Ready for planning

<domain>
## Phase Boundary

Three complete user journeys — firstJob, housingPurchase, newJob — verified end-to-end with integration tests that fail if any link in the chain breaks. Each journey traces: intent selection → relevant calculators pre-filled → premier eclairage → plan generation → suivi entry point.

</domain>

<decisions>
## Implementation Decisions

### Journey Definition & Scope
- A "complete journey" means: intent → calculators pre-filled → premier eclairage with numbers → plan with monthly target → suivi entry point
- Journeys defined via CapSequenceEngine — extend existing retirement/budget/housing sequences with firstJob, housingPurchase, newJob step sequences
- Calculator mapping per journey:
  - firstJob: 3a overview, LPP overview
  - housingPurchase: EPL, hypotheque, affordability
  - newJob: salary comparison (rente-vs-capital), LPP transfer (rachat), 3a optimization
- Journey state persisted in CapMemoryStore — existing persistence with step completion tracking from Phase 3

### Integration Test Architecture
- Flutter widget tests with mocked providers — same pattern as persona_marc_test.dart, no device/emulator needed for CI
- Each journey step asserts output exists AND navigation succeeds — test verifies each step produces non-null output, next screen renders, final state is correct
- Test data from golden couple (Julien) profile — pre-built CoachProfile with known values, assertions against expected outputs
- One test file per journey — firstjob_journey_test.dart, housing_journey_test.dart, newjob_journey_test.dart for clear failure isolation

### Journey Gaps to Wire
- firstJob journey starts via intentChipPremierEmploi (new chip) or intentChipChangement — maps to firstJob life event family, triggers CapSequence with 3a + LPP steps
- housingPurchase connects to check-in via plan generation — housing savings target → monthly check-in tracks contributions toward it (reuses Phase 4+5 infrastructure)
- newJob salary comparison: coach suggests /rente-vs-capital pre-filled with current + new salary — user sees impact of job change on retirement projection
- Add firstJob and newJob to IntentRouter — extend existing 7 mappings to 9 with appropriate stressType and suggestedRoute

### Claude's Discretion
- Exact CapSequence step definitions (number of steps, step names)
- Test assertion granularity (which intermediate values to check)
- IntentRouter stressType and suggestedRoute choices for new mappings
- Error handling for incomplete journeys (user drops off mid-flow)

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- CapSequenceEngine (lib/services/cap_sequence_engine.dart): builds multi-step journeys, existing retirement/budget/housing sequences
- CapMemoryStore (lib/models/cap_sequence.dart): step completion persistence
- IntentRouter (lib/services/coach/intent_router.dart): 7 onboarding chip → life event mappings
- ProactiveTriggerService (lib/services/coach/proactive_trigger_service.dart): 8 triggers with lifecycle awareness
- LifecycleDetector (lib/services/lifecycle/lifecycle_detector.dart): 7 lifecycle phases
- persona_marc_test.dart / persona_lea_test.dart: reference integration test pattern
- PlanTrackingService + PlanRealityCard: plan adherence tracking from Phase 5
- RouteSuggestionCard + prefill pipeline: calculator pre-fill from Phase 6

### Established Patterns
- Intent chips → IntentMapping → CapSequenceEngine → journey steps
- GoRouter extras for calculator prefill
- Mocked SharedPreferences + CoachProfile builders in tests
- ProactiveTriggerService cooldown + engagement suppression

### Integration Points
- IntentRouter: add firstJob + newJob mappings
- CapSequenceEngine: add journey definitions
- OnboardingIntentScreen: new intent chips
- CoachProfile: journey state via checkIns + contributionPlan
- Calculator screens: already pre-fill from Phase 6

</code_context>

<specifics>
## Specific Ideas

- Golden couple test: Julien selecting "Premier emploi" should trace through 3a → LPP → premier eclairage → plan → check-in prompt
- Each test file should be standalone — no shared test state between journeys
- Tests must fail if any navigation step returns null or wrong screen

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>
