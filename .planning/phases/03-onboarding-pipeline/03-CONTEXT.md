# Phase 3: Onboarding Pipeline - Context

**Gathered:** 2026-04-05
**Status:** Ready for planning
**Mode:** Auto-generated (autonomous smart discuss)

<domain>
## Phase Boundary

A user who selects an intent chip on the onboarding screen receives a personalized premier eclairage with a concrete Swiss-specific number within 3 minutes, and lands on a contextual home screen — not a generic dashboard.

Three builds required:
1. Intent-to-goal mapping (7 onboarding chips → goalIntentTag + stressType + suggested route)
2. First-landing premier eclairage card on MintHomeScreen driven by selected intent
3. First-session coach opener seeded from intent (not generic silent opener)

</domain>

<decisions>
## Implementation Decisions

### D-01: Intent Mapping Architecture
Create a static const mapping in a new `intent_router.dart` (in `lib/services/coach/`). Maps 7 `intentChip*` keys to: `goalIntentTag` (for CapSequenceEngine), `stressType` (for ChiffreChocSelector), `suggestedRoute` (first calculator to surface), and `lifeEventFamily` (for ProactiveTrigger context).

### D-02: Intent Chip → Goal Family Mapping
- `intentChip3a` → `budget_overview` / `stress_budget` / `/pilier-3a`
- `intentChipBilan` → `retirement_choice` / `stress_retraite` / `/bilan-retraite`
- `intentChipPrevoyance` → `retirement_choice` / `stress_retraite` / `/prevoyance-overview`
- `intentChipFiscalite` → `budget_overview` / `stress_impots` / `/fiscalite-overview`
- `intentChipProjet` → `housing_purchase` / `stress_patrimoine` / `/achat-immobilier`
- `intentChipChangement` → `budget_overview` / `stress_budget` / `/life-events`
- `intentChipAutre` → `retirement_choice` / `stress_retraite` / `/bilan-retraite` (fallback)

### D-03: First-Landing Flow (IntentScreen → Home)
After chip tap in IntentScreen:
1. Persist intent via `ReportPersistenceService.setSelectedOnboardingIntent()` (already exists)
2. Write `goalIntentTag` to `CapMemoryStore.declaredGoals` (new wiring)
3. Compute premier eclairage: call `ChiffreChocSelector.select(profile, stressType: mappedStressType)`
4. Navigate to `/home?tab=0` (Aujourd'hui) instead of `/home?tab=1` (coach) — user sees their number first

### D-04: Premier Eclairage Card on MintHomeScreen
Add a new `PremierEclairageCard` widget as Section 0 (before Chiffre Vivant GPS) on first visit only. Shows:
- The ChiffreChoc value (formatted CHF number)
- The ChiffreChoc title and subtitle (intent-specific explanation)
- A CTA: "Comprendre" → navigates to the suggested calculator from D-02
- Auto-dismisses after user has explored ≥1 simulator (same condition as lever unlock)

### D-05: CapSequenceEngine Seeding
After intent mapping, call `CapSequenceEngine.build(profile: profile, memory: capMemory, goalIntentTag: mappedGoalTag)` to pre-generate the first journey sequence. Store in `CapMemoryStore` so the lever (Section 2) can show the first cap immediately after the premier eclairage is dismissed.

### D-06: Coach First-Session Opener
Replace the generic `_computeKeyNumber()` silent opener in `CoachChatScreen` with an intent-aware opener when `selectedOnboardingIntent` is non-null. The opener should reference the intent (e.g., "Tu t'intéresses à ta prévoyance — voici ce que MINT peut t'apporter") and include the premier eclairage number.

### D-07: Post-Onboarding Landing Differentiation
A `firstJob` intent user and a `housingPurchase` intent user must see different:
- Premier eclairage numbers (3a tax saving vs mortgage capacity)
- CTA destinations (/premier-emploi vs /achat-immobilier)
- Coach opener messages
The MintHomeScreen reads `selectedOnboardingIntent` and the `PremierEclairageCard` adapts accordingly.

### D-08: MinimalProfile Handling
If the user hasn't completed QuickStart (no salary/age/canton), the premier eclairage falls back to a pedagogical mode (ChiffreChocSelector already supports `confidenceMode: pedagogical`). Show a generic Swiss-average number with a prompt to complete profile for personalized results.

### D-09: Intent Persistence and Replay
The selected intent persists across sessions via `ReportPersistenceService`. The premier eclairage card and intent-aware opener should only show on the FIRST session (use a `hasSeenPremierEclairage` flag in SharedPreferences). Subsequent sessions use the normal home screen flow.

### Claude's Discretion
- Exact wording of coach opener messages per intent
- Animation/transition style for PremierEclairageCard
- Whether to show a skeleton/loading state while ChiffreChocSelector computes
- Error handling if ChiffreChocSelector returns null (fallback to generic welcome)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Onboarding
- `apps/mobile/lib/screens/onboarding/intent_screen.dart` — Current intent chip implementation
- `apps/mobile/lib/screens/onboarding/quick_start_screen.dart` — Profile data collection

### Financial Engine
- `apps/mobile/lib/services/chiffre_choc_selector.dart` — Premier eclairage number generation (stressType param)
- `apps/mobile/lib/services/cap_sequence_engine.dart` — Journey sequence builder (goalIntentTag param)
- `apps/mobile/lib/services/cap_memory_store.dart` — Journey state persistence (declaredGoals field)

### Home Screen
- `apps/mobile/lib/screens/main_tabs/mint_home_screen.dart` — Aujourd'hui tab (4 sections)

### Coach
- `apps/mobile/lib/screens/coach/coach_chat_screen.dart` — Coach chat with _computeKeyNumber opener
- `apps/mobile/lib/services/coach/proactive_trigger_service.dart` — Proactive nudge engine

### Persistence
- `apps/mobile/lib/services/report_persistence_service.dart` — Intent persistence (setSelectedOnboardingIntent)

</canonical_refs>

<specifics>
## Specific Ideas

- The 3-minute target means no heavy computation at onboarding. ChiffreChocSelector is fast (< 100ms with MinimalProfile).
- CapSequenceEngine.build() is synchronous and returns immediately — no async barrier.
- Use the existing `CoachEntryPayload` pattern for passing intent context to the coach tab.
- The `PremierEclairageCard` should follow MINT's design system: MintColors, MintSpacing, Montserrat for the number display.

</specifics>

<deferred>
## Deferred Ideas

- Cross-device intent sync (CapMemoryStore TODO at line 21) → Phase 5 or later
- Intent revision (letting users change their intent after onboarding) → Phase 7 UX
- A/B testing different premier eclairage presentations → post-launch

</deferred>

---

*Phase: 03-onboarding-pipeline*
*Context gathered: 2026-04-05 via autonomous smart discuss*
