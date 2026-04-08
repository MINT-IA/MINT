# Phase 4: Moteur d'Anticipation - Context

**Gathered:** 2026-04-06
**Status:** Ready for planning

<domain>
## Phase Boundary

MINT proactively surfaces timely financial signals before the user thinks to ask. Rule-based deterministic triggers (zero LLM cost) with compliance-validated educational alerts, frequency capping, and dismiss/snooze logic.

Requirements: ANT-01, ANT-02, ANT-03, ANT-04, ANT-05, ANT-06, ANT-07, ANT-08

</domain>

<decisions>
## Implementation Decisions

### Trigger Engine
- Rule-based triggers: deterministic, zero LLM cost — per ANT-08
- Swiss fiscal calendar triggers: 3a deadline (Dec 31), cantonal tax declaration deadlines, LPP rachat windows — per ANT-01
- Profile-driven triggers: salary increase → 3a max recalculation, age milestone → LPP bonification rate change — per ANT-02
- LLM used only for optional narrative enrichment of alert text (not for trigger logic)

### Alert Format & Compliance
- AlertTemplate enum: Educational format (title + fact + source + simulatorLink) — per ANT-03
- ComplianceGuard.validateAlert() validates every alert before display — per ANT-04
- Zero banned terms, zero personalized imperatives ("tu devrais" = blocked)
- Every alert links to relevant simulator or educational content

### Frequency & Dismissal
- Frequency cap: max 2 anticipation signals per user per week on Aujourd'hui — per ANT-05
- Card ranking: priority_score = timeliness × user_relevance × confidence — top 2 as cards, rest in expandable section — per ANT-06
- Dismissal UX: each signal card has "Got it" or "Remind me later" — snooze logic per trigger type — per ANT-07

### Claude's Discretion
- Trigger evaluation timing (app launch, session start, background check)
- Specific cantonal tax deadline data source
- Snooze duration per trigger type
- Card ranking weight formula details
- Expandable "See more" section implementation

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `services/financial_core/` — calculators for 3a max, LPP bonification rates, tax
- `providers/coach_profile_provider.dart` — profile data for trigger evaluation
- `services/biography/` — Phase 3 biography facts feed trigger detection
- `constants/social_insurance.dart` — Swiss regulatory constants
- `widgets/` — MintSurface, card components for alert display

### Integration Points
- Aujourd'hui tab (mint_home_screen.dart) — alert cards display here
- CoachProfile — trigger evaluation reads profile data
- Biography — salary changes, age milestones detected from biography facts
- ComplianceGuard — alert validation before display

</code_context>

<specifics>
## Specific Ideas

- ANT-01: 3a deadline Dec 31, cantonal deadlines vary by canton, LPP rachat window = anytime but awareness spike near year-end
- ANT-02: Salary increase detection from biography (Phase 3) → recalculate 3a max (7'258 vs 36'288). Age milestone → LPP bonification rate change (7%→10%→15%→18%)
- ANT-05: 2/week cap prevents alert fatigue
- ANT-08: Rule-based = instant, deterministic, testable, free

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>
