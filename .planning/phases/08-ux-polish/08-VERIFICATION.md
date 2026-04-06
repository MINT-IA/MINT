---
phase: 08-ux-polish
verified: 2026-04-05T00:00:00Z
status: human_needed
score: 4/4 must-haves verified
human_verification:
  - test: "Open MINT on device, navigate to Aujourd'hui tab. Trigger a signal card swap (e.g. by dismissing a signal or updating a profile field that changes the signal). Observe the transition between signal card states."
    expected: "Card transition uses a smooth crossfade (300ms in, 150ms out) — no hard pop/flash. Empty state ('Tout est a jour pour l'instant.') appears if no signal available."
    why_human: "AnimatedSwitcher crossfade requires live rendering on device; can't verify absence-of-flash programmatically from static analysis."
  - test: "Open the Aujourd'hui tab on a profile with <95% confidence score (any partially-filled profile). Observe the ConfidenceScoreCard below the FinancialPlanCard."
    expected: "Card shows score percentage, zone label (Bonne estimation / Estimation large / On devine beaucoup), and a tappable enrichment action ('Pour aller plus loin : [action label]'). Tapping the CTA navigates to profile enrichment."
    why_human: "Live data rendering from CoachProfile and navigation callback require device testing."
  - test: "Open Explorer tab with a profile where salaireBrutMensuel = 0 (no salary set). Observe hub card visual states for Retraite, Fiscalite, Logement hubs."
    expected: "These 3 hubs appear at opacity 0.55 (blocked state), with a locked label. Tapping them opens a DraggableScrollableSheet listing missing fields and a 'Completer mon profil' CTA."
    why_human: "Opacity values and bottom sheet appearance require visual confirmation on device."
  - test: "From a fresh session, tap a chip on the IntentScreen (/onboarding/intent). Observe the transition to the next screen. Then navigate to /coach/chat and observe the transition."
    expected: "Both transitions use a fade (easeOutQuart, ~350ms) instead of the default Material horizontal slide push."
    why_human: "Transition style (fade vs. slide) requires live rendering on device to confirm visually."
---

# Phase 8: UX Polish Verification Report

**Phase Goal:** The Aujourd'hui tab animates naturally, ConfidenceScore is visible and actionable, Explorer reflects profile readiness, and navigation transitions feel guided
**Verified:** 2026-04-05T00:00:00Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| #  | Truth                                                                                                                                        | Status     | Evidence                                                                                                  |
|----|----------------------------------------------------------------------------------------------------------------------------------------------|------------|-----------------------------------------------------------------------------------------------------------|
| 1  | When a signal card on Aujourd'hui is dismissed or replaced, the transition uses AnimatedSwitcher crossfade — no hard refresh or flash        | ✓ VERIFIED | `AnimatedSwitcher` with `MintMotion.standard`/`fast`, `ValueKey` per card type, `disableAnimations` guard in `mint_home_screen.dart` lines 364–380 |
| 2  | ConfidenceScore is visible on Aujourd'hui with an explanation of which single action would improve it most                                    | ✓ VERIFIED | `ConfidenceScoreCard` imported and rendered in `mint_home_screen.dart` (line 226), fed by `ConfidenceScorer.scoreEnhanced(profile).axisPrompts` (line 220/228) |
| 3  | Explorer hubs show a visual state reflecting profile completeness — greyed/locked when required fields are missing                           | ✓ VERIFIED | `_HubReadinessLevel` enum + `_evaluateHub()` + `_isFieldPresent()` in `explore_tab.dart`; opacity 0.55/0.85/1.0 applied per level (line 669); `DraggableScrollableSheet` for blocked state |
| 4  | Screens in the onboarding journey path use CustomTransitionPage fade — not the default Material slide push                                   | ✓ VERIFIED | `_fadeTransitionPage()` helper with `MintMotion.page` (350ms) + `curveEnter` in `app.dart` lines 155–175; applied to `/onboarding/intent` (line 919) and `/coach/chat` (line 378–394) |

**Score:** 4/4 truths verified

### Deferred Items

None. All 4 roadmap success criteria are addressed in this phase.

**Note on SC4 partial route coverage:** The roadmap lists `/onboarding/premier-eclairage` and `/coach` (shell tab) as fade candidates. Neither exists as a push destination — premier eclairage is an inline widget on MintHomeScreen (PremierEclairageCard), and the coach shell tab is not navigated to via `context.push`. The 2 routes that exist as actual push destinations (`/onboarding/intent`, `/coach/chat`) both use fade. This is the correct implementation given the actual route architecture.

### Required Artifacts

| Artifact                                                                              | Expected                                                              | Status     | Details                                                                                                   |
|---------------------------------------------------------------------------------------|-----------------------------------------------------------------------|------------|-----------------------------------------------------------------------------------------------------------|
| `apps/mobile/lib/widgets/home/confidence_score_card.dart`                            | ConfidenceScoreCard widget with ConfidenceBar + top enrichment action | ✓ VERIFIED | 174 lines; exports `ConfidenceScoreCard`; score bar, zone label, enrichment CTA, error state all present  |
| `apps/mobile/lib/screens/main_tabs/mint_home_screen.dart`                            | AnimatedSwitcher on signal card slot + ConfidenceScoreCard integration | ✓ VERIFIED | Contains `AnimatedSwitcher`, `ValueKey('signal_proactif')`, `ValueKey('empty_signal')`, `ConfidenceScoreCard` import and render |
| `apps/mobile/lib/screens/main_tabs/explore_tab.dart`                                 | ReadinessGate-aware hub cards with opacity, indicator dot, locked overlay | ✓ VERIFIED | Contains `_HubReadinessLevel`, `_evaluateHub`, `_isFieldPresent`, opacity 0.55/0.85, `DraggableScrollableSheet`, `Semantics` |
| `apps/mobile/lib/app.dart`                                                            | CustomTransitionPage on 3 onboarding routes                           | ✓ VERIFIED | `_fadeTransitionPage()` helper present; `pageBuilder` applied to `/onboarding/intent` and `/coach/chat` |
| `apps/mobile/test/widgets/home/confidence_score_card_test.dart`                      | Widget tests covering all states                                      | ✓ VERIFIED | 8 testWidgets covering score=75/50/30, enrichment label, perfect state (score=96), error state, tap callback |
| `apps/mobile/test/screens/main_tabs/explore_tab_readiness_test.dart`                 | Tests covering ready/partial/blocked readiness states                  | ✓ VERIFIED | 14 tests covering complete profile ready, missing salary blocks 3 hubs, partial states, famille/sante always ready |

### Key Link Verification

| From                            | To                            | Via                                      | Status     | Details                                                                                     |
|---------------------------------|-------------------------------|------------------------------------------|------------|---------------------------------------------------------------------------------------------|
| `confidence_score_card.dart`    | `confidence_scorer.dart`      | `EnhancedConfidence.axisPrompts`         | ✓ WIRED    | `EnrichmentPrompt` type imported from `confidence_scorer.dart`; `enrichmentPrompts.first.label` rendered |
| `mint_home_screen.dart`         | `confidence_score_card.dart`  | import + render in `build()`             | ✓ WIRED    | Line 40: import; line 226: `ConfidenceScoreCard(score: enhanced.combined, enrichmentPrompts: enhanced.axisPrompts)` |
| `explore_tab.dart`              | ReadinessGate logic           | `_evaluateHub()` per hub                 | ✓ WIRED    | Inline implementation in `explore_tab.dart` — `ReadinessGate` service doesn't exist in codebase; equivalent field-check logic implemented directly (documented deviation) |
| `app.dart`                      | `mint_motion.dart`            | `MintMotion.page` for transition duration | ✓ WIRED    | Line 3 import; lines 162–172: `MintMotion.page`, `MintMotion.standard`, `MintMotion.curveEnter` |

### Data-Flow Trace (Level 4)

| Artifact                          | Data Variable            | Source                                | Produces Real Data | Status      |
|-----------------------------------|--------------------------|---------------------------------------|--------------------|-------------|
| `ConfidenceScoreCard`             | `score`, `enrichmentPrompts` | `ConfidenceScorer.scoreEnhanced(profile)` — geometric mean of completeness/accuracy/freshness axes | Yes — 180+ lines of computation in `confidence_scorer.dart` reading actual `CoachProfile` fields | ✓ FLOWING  |
| `explore_tab.dart` hub cards      | `readiness.level`, `readiness.missingFields` | `_evaluateHub(hubKey, profile)` — reads `profile.salaireBrutMensuel`, `profile.birthYear`, `profile.canton` etc. | Yes — real field reads with semantic "not set" detection | ✓ FLOWING  |

### Behavioral Spot-Checks

Step 7b: SKIPPED (no runnable entry points without starting Flutter dev server or device)

### Requirements Coverage

| Requirement | Source Plan | Description                                                                                  | Status    | Evidence                                                                  |
|-------------|-------------|----------------------------------------------------------------------------------------------|-----------|---------------------------------------------------------------------------|
| UXP-01      | 08-01-PLAN  | Signal cards on Aujourd'hui tab animate on data change (AnimatedSwitcher, not hard refresh)  | ✓ SATISFIED | `AnimatedSwitcher` with `MintMotion.standard`/`fast`, `ValueKey` per card type, `disableAnimations` guard |
| UXP-02      | 08-01-PLAN  | ConfidenceScore visible to user with explanation of what improves it                         | ✓ SATISFIED | `ConfidenceScoreCard` on Aujourd'hui reading `enhanced.axisPrompts` — top action displayed |
| UXP-03      | 08-02-PLAN  | Explorer hubs show ReadinessGate state (greyed/locked based on profile completeness)         | ✓ SATISFIED | 3 visual states (1.0/0.85/0.55 opacity) + blocked bottom sheet + partial warning dot |
| UXP-04      | 08-02-PLAN  | Navigation transitions feel guided (CustomTransitionPage on journey screens)                 | ✓ SATISFIED | `_fadeTransitionPage()` applied to `/onboarding/intent` + `/coach/chat` |

All 4 phase-8 requirement IDs accounted for. No orphaned requirements for Phase 8 in REQUIREMENTS.md.

### Anti-Patterns Found

No TODOs, FIXMEs, placeholders, empty handlers, or stub patterns found in phase-modified files:
- `confidence_score_card.dart` — substantive implementation, no stubs
- `mint_home_screen.dart` (modified sections) — real data path, no hardcoded empty values
- `explore_tab.dart` (modified sections) — live field reads, no static returns
- `app.dart` (modified sections) — real transition builder, no empty implementations

### Human Verification Required

#### 1. AnimatedSwitcher Crossfade Visual Check

**Test:** On a real device (or Flutter debug mode), navigate to Aujourd'hui tab. If a signal card is showing, dismiss it or change a profile field to trigger a card swap.
**Expected:** The transition between the signal card and empty state (or between two signal cards) is a smooth fade crossfade (~300ms). There is no hard cut, flash, or position jump.
**Why human:** The absence of a visual flash on card swap cannot be verified by static code analysis. AnimatedSwitcher with FadeTransition is wired correctly in code, but the actual rendered visual requires device confirmation.

#### 2. ConfidenceScoreCard Live Data Display

**Test:** Open Aujourd'hui tab on a profile with partial data (e.g., salary set but no LPP certificate). Observe the ConfidenceScoreCard below the FinancialPlanCard section.
**Expected:** Card shows a score percentage (e.g., 45%), a zone label ("Estimation large"), and a tappable enrichment action ("Pour aller plus loin : [specific field label]"). When score >= 95 with complete data, the card shows "Ta projection est tres precise — rien a ajouter pour l'instant." instead.
**Why human:** Live CoachProfile data rendering and the exact enrichment prompt wording require device confirmation.

#### 3. Explorer Readiness States Visual Check

**Test:** Open Explorer tab with a profile where salary is 0 (unset). Compare to the same tab with salary filled in.
**Expected:** Hubs Retraite, Fiscalite, Logement appear visually muted (opacity 0.55) with a locked label when salary is missing. Tapping a blocked hub opens a bottom sheet listing "Ton salaire" as missing and a "Completer mon profil" button. With salary filled, these hubs return to full opacity and normal tap behavior. Partial hubs (optional fields missing) show a small orange warning dot at the top-right of the icon.
**Why human:** Visual opacity differences and bottom sheet layout require device rendering to confirm legibility and UX feel.

#### 4. Fade Transition on Journey Routes

**Test:** From the IntentScreen (/onboarding/intent), select a chip and observe the screen transition. Also navigate to /coach/chat from the Aujourd'hui tab.
**Expected:** Both route navigations fade in (approximately 350ms, easeOutQuart curve) instead of the standard Material horizontal slide. The transition should feel calmer and more intentional than a default push.
**Why human:** Visual transition style (fade vs. slide) requires live device rendering to confirm the effect is perceptible and correct.

### Gaps Summary

No gaps found. All 4 observable truths are verified, all key artifacts exist and are substantive, all key links are wired, and all 4 requirement IDs are satisfied. The 4 items above require human visual confirmation on device but do not represent code deficiencies.

---

_Verified: 2026-04-05T00:00:00Z_
_Verifier: Claude (gsd-verifier)_
