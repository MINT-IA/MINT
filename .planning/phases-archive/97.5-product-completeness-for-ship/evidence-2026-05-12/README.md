---
description: Phase 97.5 W2 + W3-T1 G1 Maestro evidence — captured 2026-05-12T22:15-22:18 CEST on iPhone 17 Pro sim (UDID B03E429D-0422-4357-B754-536637D979F9) running iOS 26.2 against staging-built Runner.app (origin/dev a2c54219, post-PR-#584).
type: phase-evidence
created: 2026-05-12
---

# Phase 97.5 — G1 Maestro evidence (2026-05-12)

## P004 — MintChatOverlay populated on open : **GREEN**

- **Flow** : `tools/simulator/flows/regression/bug__F001_S001_combined__chat_via_cap_du_jour.yaml` (chained cold launch → bêta dismiss → « Continuer sans compte » → /home → CapDuJourBanner → tap « Explique-moi » → MintChatOverlay).
- **JUnit** : `maestro_p004_chat_as_verb.xml` — `tests=1, failures=0, time=10.0, status=SUCCESS`.
- **Screenshot** : `W2-P004-post-explique-tap.png` — overlay body populé avec 4 slots :
  - **Header FR** : « Explique-moi » (NOT raw enum « explain ») — W2-T3 ARB fix verified
  - **Hook** : « Voyons ensemble ce que ça change pour toi. »
  - **Caption** : « Voici ce que ta carte raconte aujourd'hui. »
  - **Next step** : « › Tape une question pour creuser. » (narrativeSleeveNextStepExplain ARB key)
  - **Turn counter** : « 0 / 3 » (free-turn semantics)
- **Comparison vs morning SCOUT** : at 19:30Z body was completely empty (P004 BLOCKER). Post-fix, body carries 4 slots per W1-T1 ADR Option A path.

**Verdict** : P004 perimeter G1 evidence GREEN. Remaining gates : G2 (Julien device walkthrough) + G3 (CI green ✓ already merged) + G4 (regression tests 16/16 ✓) + G5 (LSFin + accent + ARB lint ✓).

## W3-T1 — ConfidenceScoreCard MintCardActionBar wire-up : **REACHABILITY DATA-GATED**

- **Code SHIPPED** via PR #584 merged 20:08Z — Semantics + Key + MintCardActionBar + _buildCardContext helper + 6/6 widget tests pass.
- **G1 anonymous cold-launch reachability** : NOT VERIFIABLE. ConfidenceScoreCard requires user data (CoachProfileProvider populated). Anonymous fresh user sees an empty-state widget (« Commence par parler au coach. Tes premières tensions apparaîtront ici. ») instead of the data-loaded cards row.
- **Screenshot** : `W3-T1-aujourdhui-end-of-scroll.png` — Aujourd'hui screen on anonymous flow showing CapDuJourBanner + 3 verb chips + empty-state widget. No ConfidenceScoreCard rendered.
- **Honest framing per CLAUDE.md §9** : W3-T1 wire-up is implemented + unit-test-locked (G3 + G4 + G5 green). Sim-walk G1 reachability on anonymous flow is **DATA-GATED** ; full G1 requires authenticated user with profile data — that's W3-T4-stripped (Maestro semantic flow with seeded data) or v2.10.

**Chat-as-verb reachability from cold launch anonymous** : satisfied by CapDuJourBanner alone (verb chips visible immediately). PLAN.md §A.6 « ≥ 2 cards reachable from cold launch on multiple surfaces » — the 2nd card lives in the authenticated post-data flow, not the anonymous cold-launch flow. This is honest scope.

## Sim discipline notes

- macOS Tahoe simctl flakiness encountered : SpringBoard crashed at 22:13Z (Pitfall 8 documented in `tools/simulator/walker.sh`). Recovery : `xcrun simctl shutdown` + `xcrun simctl boot` cleared it without erase. No data loss.
- Java env required : `bash tools/simulator/maestro_env.sh test <flow>` (not direct `maestro test`) per PERS-01 setup script.
