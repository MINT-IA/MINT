# Phase 2: Deletion spree - Context

**Gathered:** 2026-04-09
**Status:** Ready for planning
**Mode:** Expert-panel autonomous

<domain>
## Phase Boundary

Remove ~70% of v2.2 destination surface area. Delete screens that fail the 3-second test. Don't redesign them. The space they free becomes breath. Bug 1 (auth leak) and Bug 3 (Centre de contrôle) dissolve as side effect of deletion. Bug 2 (infinite loop) was already fixed in Phase 1 (coach_chat_screen.dart payload guard patch) — Phase 2 verifies it's gone by deleting CoachEmptyState.

**Requirements covered:** KILL-01..07, BUG-01 (verify only — already fixed), BUG-02 (verify auth leak impossible).

</domain>

<decisions>
## Implementation Decisions

### Deletion Order (leaves inward, each a separate commit for git bisect)
1. **KILL-02**: Delete `CoachEmptyState` widget ("Faire mon diagnostic") — dead-end widget, source of Bug 2 loop. File: `apps/mobile/lib/screens/coach/coach_empty_state.dart` + all imports.
2. **KILL-01**: Delete `/onboarding/intent` screen — the conversation IS the diagnostic. File: `apps/mobile/lib/screens/onboarding/intent_screen.dart` + GoRoute registration in app.dart + all imports.
3. **KILL-03**: Delete `/profile/consent` Centre de contrôle as destination — remove GoRoute in app.dart, keep the consent logic code if it exists as a service (Phase 3 needs it for inline chat consent). Delete the SCREEN, not the business logic.
4. **KILL-04**: Delete Moi dashboard gamification — remove `0% — il manque...`, `+15%`, `+10%` badges, dossier completion percentage. Replace with neutral state language or simply remove the section. The Moi screen itself may survive as a chat-summoned drawer — remove only the gamification widgets, not the entire screen.
5. **KILL-05**: Delete account creation as mandatory onboarding step — remove the "Créer ton compte" screen from the onboarding GoRoute flow. Keep the auth service for later optional use. The 3D cube logo, the "Pourquoi créer un compte?" section, the 4 consent checkboxes all go.
6. **KILL-06**: Remove voice cursor N1/N2/N3 radio buttons from any user-facing surface — grep for `N1 —`, `N2 —`, `N3 —`, `Tranquille`, `Clair`, `Direct` in screens. The Moi dashboard had these. Remove them. The voice cursor functionality stays in the backend, it just loses user-facing exposure until Phase 3 rebuilds it in chat (CHAT-05).
7. **KILL-07**: Remove Explorer hub screens from GoRouter destinations. The 7 hubs (Retraite, Famille, Travail, Logement, Fiscalité, Patrimoine, Santé) lose their GoRoute. The underlying screen files and calculator widgets STAY — they become chat-summoned drawers in Phase 3. Also remove Explorer from the tab bar.

### BUG-01 Verification (already fixed)
- Coach_chat_screen.dart was patched in Phase 1 (01-01b executor): the `_hasProfile` guard now checks `widget.entryPayload == null && widget.initialPrompt == null` before short-circuiting to empty state.
- Phase 2 verifies by DELETING CoachEmptyState entirely (KILL-02). If the app still builds and tests pass, the bug is structurally eliminated.

### BUG-02 Verification (auth leak impossible)
- Phase 1 installed scope-based guards (NAV-01, NAV-02). Phase 2 deletes `/profile/consent` (KILL-03).
- Write one integration test: from any public/onboarding scope, attempt `context.go('/profile/consent')` or `context.go('/profile')` → verify redirect to landing. This is the tombstone test for Bug 1.

### Test Impact Management
- Each deletion commit MUST also update/delete co-located tests that import the deleted screen.
- Tests that test business logic (not the screen) should be preserved by updating imports.
- Tests that test the screen's rendering/behavior get deleted with the screen.
- Track test count delta per commit. It's OK for total count to go DOWN — we're deleting real screens.

### Tab Bar & Navigation Surface
- After KILL-01 and KILL-07, the 3-tab shell (Aujourd'hui | Coach | Explorer) collapses. Expert panel decision: **the shell becomes chat-only for now.** Phase 3 (Chat-as-shell rebuild) will design the final navigation surface. Phase 2 just removes what's broken.
- Minimal viable shell post-Phase 2: landing → chat. That's it. No tabs. No drawer. No profile.

### Gate 0 (DEVICE-01) for Phase 2
- THIS IS THE FIRST USER-FACING PHASE. Gate 0 is real here.
- After all deletions, Julien installs TestFlight build and verifies:
  (a) Landing screen appears (1 CTA)
  (b) Tapping CTA goes to coach chat directly
  (c) No intent screen, no "Faire mon diagnostic", no Centre de contrôle reachable
  (d) Chat works (sends a message, gets a response)
- Screenshots from Julien required before Phase 3 starts.

### Claude's Discretion
- Whether to keep empty Moi screen as a shell or delete it entirely (recommendation: delete, rebuild in Phase 3 as chat drawer)
- Whether to keep the 3-tab ShellRoute structure with 1 active tab or simplify to a single-page app temporarily
- Error handling for deep links to deleted routes (redirect to /coach/chat)

</decisions>

<code_context>
## Existing Code Insights

### Files to delete or gut
- `apps/mobile/lib/screens/coach/coach_empty_state.dart` (KILL-02)
- `apps/mobile/lib/screens/onboarding/intent_screen.dart` (KILL-01)
- `apps/mobile/lib/screens/profile/consent_screen.dart` or wherever Centre de contrôle lives (KILL-03)
- Account creation screen in `apps/mobile/lib/screens/auth/register_screen.dart` route registration (KILL-05)
- Voice cursor radio buttons in Moi screen (KILL-06)
- Explorer hub routes in app.dart (KILL-07)

### Files to keep (business logic, not UI)
- `apps/mobile/lib/services/` — all services stay
- `apps/mobile/lib/providers/` — providers stay (Phase 3 rewires them)
- `apps/mobile/lib/widgets/coach/` — coach chat widgets stay
- Calculator widgets and screens stay as files — they just lose GoRoute registrations

### Integration Points
- `apps/mobile/lib/app.dart` — GoRoute deletions happen here (ScopedGoRoute registrations)
- Tab bar / ShellRoute — collapses from 3 tabs to 1 or goes away
- Tests throughout `apps/mobile/test/` — imports of deleted screens break, must be updated

</code_context>

<specifics>
## Specific Ideas

- The deletion spree is the most satisfying phase of v2.3 — every file deleted is cognitive load removed from the user.
- After this phase, MINT becomes: landing → chat. That's it. The simplest app possible. Phase 3 adds intelligence back via chat-summoned drawers.
- The guard snapshot golden file from Phase 1 (GATE-04) will need updating after route deletions — this is expected and correct.

</specifics>

<deferred>
## Deferred Ideas

- Chat-summoned drawers for calculators, profile, documents → Phase 3
- Inline consent in chat → Phase 3
- Tone preference in chat → Phase 3
- Rebuilt landing screen (POLISH-01) → Phase 5

</deferred>
