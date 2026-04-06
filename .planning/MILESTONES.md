# Milestones

## v1.0 MVP Pipeline — Largely shipped — 2 functional gaps open

**Phases completed:** 8 phases, 20 plans, 34 tasks

**Key accomplishments:**

- Deleted lib/services/coach/coach_narrative_service.dart (206-line duplicate) and verified zero broken imports across 6451 passing tests
- 1. [Rule 3 - Blocking] NavigationShellState class embedded in pulse_screen.dart
- One-liner:
- SLM path
- One-liner:
- One-liner:
- One-liner:
- FinancialPlan model + SharedPreferences service + reactive provider with postFrameCallback-safe staleness detection, plus 12 plan card i18n keys across 6 languages
- Calculator-backed plan generation with ArbitrageEngine branching, inline chat PlanPreviewCard with T-04-04 threat mitigation (numbers from provider not LLM), and FinancialPlanProvider registered with staleness wiring in app.dart
- One-liner:
- WidgetRenderer
- One-liner:
- One-liner:
- One-liner:
- 63 standalone Flutter journey tests covering firstJob (19), housingPurchase (21), and newJob (23) E2E flows — intent chip to CapSequence step status to calculator routes, verified against Julien golden profile.
- Fixed 2 navigation-breaking GoRouter route mismatches and added stress_prevoyance case routing firstJob premier eclairage to 3a/compound growth numbers instead of hourly rate
- AnimatedSwitcher crossfade on signal card slot (300ms in/150ms out) and new ConfidenceScoreCard surfacing projection precision with top enrichment action on Aujourd'hui tab
- Explorer hubs show opacity/dot/blocked states driven by CoachProfile field presence, and onboarding routes (/onboarding/intent, /coach/chat) use CustomTransitionPage 350ms fade replacing Material slide

---
