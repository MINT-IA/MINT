# Roadmap: MINT v1.0 UX Journey

## Overview

This milestone transforms MINT's disconnected components into a seamless user journey. All required infrastructure already exists — the work is three wiring gaps and their downstream payoffs. Phases are ordered by dependency: cleanup unblocks everything, tool dispatch unblocks onboarding, onboarding unblocks plan generation, plan generation unblocks suivi, and the three verified life event journeys prove the whole pipeline works end-to-end. UX polish completes the milestone.

## Phases

- [ ] **Phase 1: Pre-Refactor Cleanup** - Eliminate duplicate services and orphan routes before any wiring begins
- [ ] **Phase 2: Tool Dispatch** - Wire coach tool calls to the Flutter UI so LLM outputs reach the user
- [ ] **Phase 3: Onboarding Pipeline** - Connect intent selection to journey engine and deliver first premier eclairage in under 3 minutes
- [ ] **Phase 4: Plan Generation** - Coach produces persistent, chiffered financial plans from user goals
- [ ] **Phase 5: Suivi & Check-in** - Monthly check-ins, progress visualization, and cross-session memory
- [ ] **Phase 6: Calculator Wiring** - Profile pre-fill across all calculator entry screens
- [ ] **Phase 7: Life Event Journeys** - Three verified end-to-end journeys (firstJob, housingPurchase, newJob)
- [ ] **Phase 8: UX Polish** - Signal card animations, confidence score visibility, ReadinessGate-aware Explorer

## Phase Details

### Phase 1: Pre-Refactor Cleanup
**Goal**: The codebase has no duplicate service copies, no orphan routes, and a verified route table — safe to build on
**Depends on**: Nothing (first phase)
**Requirements**: CLN-01, CLN-02, CLN-03
**Success Criteria** (what must be TRUE):
  1. A grep for each of the three duplicate service pairs returns exactly one canonical import path across the entire codebase
  2. Every one of the 67 canonical routes is either live (has a screen), redirected (explicit alias), or archived (explicit comment) — no silent dead ends
  3. Dead screens (no route pointing to them) are removed; flutter analyze still reports 0 errors after removal
**Plans:** 3 plans
Plans:
- [x] 01-01-PLAN.md — Resolve 3 duplicate service pairs (delete non-canonical copies)
- [x] 01-02-PLAN.md — Audit route table, fix stale comment, delete dead screens
- [x] 01-03-PLAN.md — Gap closure: delete 2 remaining non-canonical service copies + fix test imports

### Phase 2: Tool Dispatch
**Goal**: Coach tool calls (show_fact_card, route_to_screen, show_score_gauge, etc.) reach the Flutter UI and render the appropriate inline widgets
**Depends on**: Phase 1
**Requirements**: TDP-01, TDP-02, TDP-03, TDP-04
**Success Criteria** (what must be TRUE):
  1. Asking "comment fonctionne mon LPP?" in coach chat produces an inline FactCard widget in the message bubble — not a text-only response
  2. A RouteSuggestionCard appears in chat when the LLM calls route_to_screen — tapping it navigates to the suggested screen
  3. CoachRichWidgetBuilder renders widgets based on LLM tool decisions, not keyword matching — verified by disabling keyword fallback and confirming output is unchanged
  4. ChatToolDispatcher exists as a distinct class, parses tool markers from every CoachResponse, and dispatches to the appropriate UI handler
**Plans:** 2 plans
Plans:
- [x] 02-01-PLAN.md — Create ChatToolDispatcher class + add route_to_screen to WidgetRenderer
- [ ] 02-02-PLAN.md — Wire dispatcher into CoachChatScreen, remove legacy dispatch + keyword builder

### Phase 3: Onboarding Pipeline
**Goal**: A user who selects an intent chip on the onboarding screen receives a personalized premier eclairage with a concrete Swiss-specific number within 3 minutes, and lands on a contextual home screen — not a generic dashboard
**Depends on**: Phase 2
**Requirements**: ONB-01, ONB-02, ONB-03, ONB-04
**Success Criteria** (what must be TRUE):
  1. From cold launch, a user selects an intent chip and sees a personalized premier eclairage (containing at least one Swiss-specific number relevant to their intent) within 3 minutes — verified on device
  2. IntentScreen selection triggers CapSequenceEngine to generate a relevant first journey sequence — verified by checking CapMemoryStore.activeGoal is set after chip tap
  3. JourneyTrigger connects the selected intent to the correct calculator or insight flow — verified by tracing the complete code path from intent tap to coach first response
  4. Post-onboarding landing screen content reflects the selected intent (not generic) — a firstJob intent lands differently than a housingPurchase intent
**Plans**: TBD
**UI hint**: yes

### Phase 4: Plan Generation
**Goal**: The coach generates a persistent, chiffered financial plan from the user's declared goal — visible outside chat history and adaptive to profile changes
**Depends on**: Phase 3
**Requirements**: PLN-01, PLN-02, PLN-03, PLN-04
**Success Criteria** (what must be TRUE):
  1. Telling the coach "j'veux acheter un appartement dans 3 ans" produces a plan with a monthly savings amount, intermediate milestone targets, and a projected outcome — all with numbers
  2. The generated plan is accessible from the Aujourd'hui tab or profile drawer without scrolling through chat history
  3. When the user's salary changes in their profile, the plan's monthly amount updates to reflect the new figure
**Plans**: TBD
**UI hint**: yes

### Phase 5: Suivi & Check-in
**Goal**: Users are proactively nudged to check in monthly, check-ins feel conversational rather than form-like, and progress against the plan is visible on Aujourd'hui
**Depends on**: Phase 4
**Requirements**: SUI-01, SUI-02, SUI-03, SUI-04, SUI-05
**Success Criteria** (what must be TRUE):
  1. A proactive nudge (local notification) appears when a monthly check-in is due — not only available on demand
  2. The check-in flow is conversational: the coach asks "combien as-tu verse ce mois?" and the user answers in chat — no standalone form screen
  3. PlanRealityCard is visible on the Aujourd'hui tab showing plan vs. actual progress
  4. Coach references a past check-in by amount ("le mois dernier tu avais verse X") — confirming cross-session memory is active
  5. The user's streak count is visible somewhere in the UI (not just tracked in background)
**Plans**: TBD
**UI hint**: yes

### Phase 6: Calculator Wiring
**Goal**: Every calculator screen opened via a coach suggestion arrives pre-filled with data MINT already knows — users are never asked to re-enter information the app has
**Depends on**: Phase 2
**Requirements**: CAL-01, CAL-02, CAL-03
**Success Criteria** (what must be TRUE):
  1. Opening /rente-vs-capital via a coach suggestion shows Julien's 70,377 CHF LPP capital pre-filled — user does not have to type it
  2. A RouteSuggestionCard tap passes prefill data through GoRouter extras to the calculator constructor — verified by inspecting the GoRouter handler in app.dart
  3. When a calculator produces a result, the relevant field (e.g., projected LPP capital) is written back to CoachProfile — verified by checking CoachProfile state before and after a simulation run
**Plans**: TBD
**UI hint**: yes

### Phase 7: Life Event Journeys
**Goal**: Three complete user journeys — firstJob, housingPurchase, newJob — are verified end-to-end on device, with integration tests that fail if any link in the chain breaks
**Depends on**: Phase 3, Phase 5, Phase 6
**Requirements**: LEJ-01, LEJ-02, LEJ-03, LEJ-04
**Success Criteria** (what must be TRUE):
  1. firstJob journey works end-to-end: intent → relevant calculators pre-filled → premier eclairage with LPP/3a numbers → plan with monthly target → suivi entry point — verified on device with a fresh profile
  2. housingPurchase journey works end-to-end: intent → EPL/mortgage calculator pre-filled → savings plan → monthly check-in prompt — verified on device
  3. newJob journey works end-to-end: intent → salary comparison → LPP transfer check → 3a optimization step — verified on device
  4. Each journey has an integration test that traces the full flow and fails if any step produces no output or a broken navigation
**Plans**: TBD
**UI hint**: yes

### Phase 8: UX Polish
**Goal**: The Aujourd'hui tab animates naturally, ConfidenceScore is visible and actionable, Explorer reflects profile readiness, and navigation transitions feel guided
**Depends on**: Phase 7
**Requirements**: UXP-01, UXP-02, UXP-03, UXP-04
**Success Criteria** (what must be TRUE):
  1. When a signal card on Aujourd'hui is dismissed or replaced, the transition uses AnimatedSwitcher crossfade — no hard refresh or flash
  2. ConfidenceScore is visible on Aujourd'hui with an explanation of which single action would improve it most — not hidden in a settings screen
  3. Explorer hubs show a visual state reflecting profile completeness (greyed/locked items when required fields are missing) — a profile with no salary sees different hub states than a complete profile
  4. Screens in the onboarding journey path (/onboarding/intent, /coach, /onboarding/premier-eclairage) use CustomTransitionPage fade — not the default Material slide push
**Plans**: TBD
**UI hint**: yes

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4 → 5 → 6 → 7 → 8

Note: Phase 6 depends on Phase 2 only (not Phase 5), so it can be planned in parallel with Phases 4-5. Execution still follows numeric order for simplicity.

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Pre-Refactor Cleanup | 0/3 | Gap closure planned | - |
| 2. Tool Dispatch | 0/2 | Planned | - |
| 3. Onboarding Pipeline | 0/? | Not started | - |
| 4. Plan Generation | 0/? | Not started | - |
| 5. Suivi & Check-in | 0/? | Not started | - |
| 6. Calculator Wiring | 0/? | Not started | - |
| 7. Life Event Journeys | 0/? | Not started | - |
| 8. UX Polish | 0/? | Not started | - |
