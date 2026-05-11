---
phase: 96
plan: 03
type: human-uat
created: 2026-05-11
status: awaiting-verdict
resume-signal: pending
---

# Phase 96 — G2 Julien sim walkthrough (HUMAN-UAT)

> Per CLAUDE.md §9 0-trust + memory `feedback_perimeter_5_gates` — G2
> is the authoritative end-to-end gate for Phase 96 close-out. No
> automation can substitute for real eyes on a TestFlight build.

## Pre-conditions

Before Julien walks through the flow, confirm :

- [ ] TestFlight build version contains commits from Plans 96-01 +
      96-02 + 96-03 (check `Settings → About → Build` against the
      latest CI sha on `dev` or `staging` branch).
- [ ] `chatTabVisible=false` set on Railway staging /config/feature-flags
      (or accept the 4-tab nav today and verify only the action bar
      path + 3-turn cap + terminal template + Explorer deep-link).
- [ ] ANTHROPIC_API_KEY present on Railway staging (per memory
      `feedback_anthropic_key_on_railway` — it IS configured).

## Walkthrough steps

1. **Setup** : Open the TestFlight build on a real device.

2. **Step 1 — Nav check** : Confirm the bottom nav shows only 3 tabs
   (Aujourd'hui / Mon Argent / Explorer). If 4 tabs are visible,
   `chatTabVisible=false` has not been pulled yet — skip this step,
   continue with step 2 onwards (the action bar path is independent
   of the nav state).

3. **Step 2 — Open card « Mon 3a 2026 »** : Tap the card on the
   Aujourd'hui surface (note : if the production card list does not
   yet wire MintCardActionBar, navigate to the Plan 96-01 demo
   screen `/coach/chat_as_verb_demo` if registered in GoRouter, or
   tell the operator to register it). Confirm :
   - The card expands to reveal the `MintCardActionBar` with 3
     verbs : « Explique-moi », « Simule », « Rassure-moi ».
   - Animation duration ~200 ms, smooth easeOutCubic.

4. **Step 3 — Tap « Explique-moi »** : Modal overlay
   (`MintChatOverlay`) slides up from the bottom. Confirm :
   - Drag handle visible at top (40×4 dp).
   - Turn counter shows `1 / 3`.
   - Coach can be typed into.

5. **Step 4 — Send 3 turns** : Send 3 messages on the same card.
   Confirm :
   - Each response renders the `NarrativeSleeve` 4-field structure
     (hook digit-free, caption with cited numbers, next_step in
     mintForest with leading ›, metaphor if applicable).
   - Hook contains NO digits (the linter is doing its job).
   - Numbers in caption have visible citation chips (Phase 94 surface).
   - Turn counter increments to `2 / 3`, then `3 / 3`.

6. **Step 5 — Trigger turn 4 cap** : Send a 4th message. Confirm :
   - Response is the verbatim D-10 terminal template :
     « Tu as exploré 3 angles sur cette carte. Pour aller plus loin,
     ouvre le simulateur depuis [Explorer →](...) — tu pourras y
     modifier les hypothèses en direct. »
   - Response was instant (zero LLM call ; no spinner / no API delay).
   - « Explorer → » is tappable as an inline link.

7. **Step 6 — Tap Explorer →** : Confirm the app navigates to the
   Explorer scene for the same card_id. Card data loaded ; user can
   modify hypotheses.

8. **Step 7 — « Simule » verb check** : Go back to Aujourd'hui. Tap
   the « Mon 3a 2026 » card again. Tap « Simule » this time. Confirm :
   - NO chat overlay opens.
   - App navigates DIRECTLY to Explorer with the card's parameters.

9. **Step 8 — Walkback simulation (optional)** : If staging has a
   `/config/feature-flags` toggle accessible AND the nav state is
   `false` today, flip `chatTabVisible=true` and confirm the 4-tab
   nav restores within the next app cold launch.

## Verdict (Julien fills in)

**Token :** _pending_

| Token | Disposition |
|-------|-------------|
| `approved` | Phase 96 closes ; v2.9 Chat-as-Verb Pivot milestone marked SHIPPED on ROADMAP.md ; TestFlight ship path activates. The `chatTabVisible=false` flag-flip is then a SEPARATE post-G2 operator decision gated on the 7-day baseline pull. |
| `approved-with-issues: <description>` | Phase 96 closes with documented residuals ; issues moved to backlog 999.x with explicit decision IDs. |
| `not approved — issue: <description>` | Phase 96 returns to revision mode ; orchestrator routes to `/gsd-plan-phase 96 --gaps` with the specific issue as input. |

**Notes / observations :**

_pending Julien sim walkthrough_

**Date of walkthrough :** _pending_

**Device :** _pending (e.g. iPhone 15 Pro on TestFlight build N)_

---
*Phase : 96-mvp-chat-as-verb*
*Plan : 03 — Wave 3 G2 gate*
*Authoritative gate per CLAUDE.md §9.4 sim-survival test.*
