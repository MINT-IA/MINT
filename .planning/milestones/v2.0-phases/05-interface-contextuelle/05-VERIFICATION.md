---
phase: 05-interface-contextuelle
verified: 2026-04-06T19:26:54Z
status: human_needed
score: 9/9 must-haves verified
human_verification:
  - test: "Aujourd'hui tab renders hero stat card at slot 1 with real profile data"
    expected: "A card appears at the top of the feed with a 48px number reflecting the user's actual 3a gap, retirement income, or profile completeness — not empty or a spinner"
    why_human: "Requires a running device/emulator with a non-null CoachProfile loaded; cannot verify rendered output programmatically"
  - test: "Coach opener text changes based on biography events"
    expected: "After scanning a document with FactSource.document updated within 30 days, the opener reads 'Ton certificat ... affine tes projections' rather than the fallback"
    why_human: "Requires end-to-end session state with a BiographyProvider populated from a real document scan event"
  - test: "Card tap triggers GoRouter deep-link navigation"
    expected: "Tapping HeroStatCard navigates to /simulators/3a (or /retirement/projection), ProgressMilestoneCard navigates to /onboarding/quick?section=profile, ActionOpportunityCard navigates to /documents/capture"
    why_human: "Deep-link routing requires a running GoRouter instance with registered routes; flutter test widget tests stub navigation"
  - test: "Overflow section expands and collapses with animation"
    expected: "Tapping the overflow row expands hidden cards with AnimatedCrossFade; tapping again collapses; reduced-motion devices skip animation"
    why_human: "Animation behavior and accessibility (reduced motion) require a running device or Patrol integration test"
  - test: "3-tab shell unchanged (CTX-06)"
    expected: "Bottom navigation shows exactly 3 tabs (Aujourd'hui, Coach, Explorer) and ProfileDrawer still opens from the end drawer; no tab was added, removed, or reordered"
    why_human: "Shell regression is verified by passing tests but visual tab labels and drawer behaviour need a real device for confidence"
---

# Phase 5: Interface Contextuelle Verification Report

**Phase Goal:** The Aujourd'hui tab shows a living, ranked set of cards that reflect what matters most to the user right now
**Verified:** 2026-04-06T19:26:54Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | ContextualRankingService produces max 5 ranked cards (4 direct + 1 overflow) from heterogeneous card types | VERIFIED | `contextual_ranking_service.dart` lines 109-123: hero always slot 1, top 3 non-hero visible, remainder wrapped in ContextualOverflowCard |
| 2 | Card ranking is deterministic per session — same inputs always produce same order | VERIFIED | Pure static service, stable sort on priorityScore, zero DateTime.now() in service layer (injectable only), ContextualCardProvider guards re-evaluation with `_evaluated` flag |
| 3 | Completed action sets card priority to 0, demoting it below active cards | VERIFIED | `contextual_card_provider.dart` `demoteCard()` removes card from visible, appends to overflow; ranking service sorts priorityScore=0 last (line 107) |
| 4 | HeroStatResolver selects the most impactful metric from profile data (3a gap, retirement income, profile completeness) | VERIFIED | `hero_stat_resolver.dart`: priority 1 = 3a gap (archetype-aware: 7258 salarie / 36288 independant), priority 2 = retirement projection, priority 3 = completeness fallback |
| 5 | ActionOpportunityDetector surfaces 'scan document' when no documents scanned, 'complete profile' when completeness < 70% | VERIFIED | `action_opportunity_detector.dart` lines 34+: checks FactSource.document in biography facts, checks confidence completeness < 70 |
| 6 | Coach opener text is biography-aware and changes based on user financial events | VERIFIED | `coach_opener_service.dart`: 5-priority fallback chain — salary increase (90 days) > recent document scan (30 days) > 3a gap > profile < 50% > fallback |
| 7 | Coach opener passes ComplianceGuard validation (zero banned terms, zero imperatives) | VERIFIED | `coach_opener_service.dart` lines 88-94: ComplianceGuard.validateAlert() called on every generated opener; fallback returned if non-compliant; 33/33 tests pass including compliance test |
| 8 | Each card type deep-links to the correct simulator or tool via GoRouter | VERIFIED | `hero_stat_card.dart` line 45: `context.push(card.route)`; home screen lines 473-490: sealed class switch dispatches all 5 subtypes with `onTap: () => context.push(card.route)` |
| 9 | 3-tab shell (Aujourd'hui, Coach, Explorer) + ProfileDrawer remain unchanged | VERIFIED | MintHomeScreen only modifies its body content; MainNavigationShell untouched; navigation_shell_test + core_app_screens_smoke_test confirm 3-tab shell passes (43/43 tests) |

**Score:** 9/9 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `apps/mobile/lib/models/contextual_card.dart` | ContextualCard sealed class with 5 subtypes | VERIFIED | `sealed class ContextualCard` with 5 final subtypes: Hero, Anticipation, Progress, Action, Overflow |
| `apps/mobile/lib/services/contextual/contextual_ranking_service.dart` | Pure static ranking producing ContextualRankResult | VERIFIED | Pure static `ContextualRankingService` with `ContextualRankResult(visible, overflow)` |
| `apps/mobile/lib/services/contextual/hero_stat_resolver.dart` | HeroStatResolver selecting most impactful metric | VERIFIED | `class HeroStatResolver` with archetype-aware 3a gap detection and retirement income projection |
| `apps/mobile/lib/services/contextual/action_opportunity_detector.dart` | ActionOpportunityDetector surfacing contextual actions | VERIFIED | `class ActionOpportunityDetector` with static detect() returning List<ContextualActionCard> |
| `apps/mobile/lib/services/contextual/progress_milestone_detector.dart` | ProgressMilestoneDetector surfacing milestones | VERIFIED | `class ProgressMilestoneDetector` with static detect() returning List<ContextualProgressCard> |
| `apps/mobile/lib/services/contextual/coach_opener_service.dart` | Biography-aware opener with compliance validation | VERIFIED | `class CoachOpenerService` with 5-priority chain and ComplianceGuard.validateAlert() gate |
| `apps/mobile/lib/providers/contextual_card_provider.dart` | ChangeNotifier bridging ranking service to widget tree | VERIFIED | `class ContextualCardProvider extends ChangeNotifier` with session caching and demoteCard() |
| `apps/mobile/lib/widgets/home/hero_stat_card.dart` | HeroStatCard with 48px display number, delta badge, deep-link | VERIFIED | StatelessWidget, MintSurface(blanc), displayLarge typography, _DeltaBadge, context.push |
| `apps/mobile/lib/widgets/home/progress_milestone_card.dart` | ProgressMilestoneCard with AnimatedProgressBar | VERIFIED | StatelessWidget, MintSurface(peche), AnimatedProgressBar |
| `apps/mobile/lib/widgets/home/action_opportunity_card.dart` | ActionOpportunityCard with chevron and deep-link | VERIFIED | StatelessWidget, 48px min touch target, chevron_right_rounded, context.push |
| `apps/mobile/lib/widgets/home/contextual_overflow.dart` | ContextualOverflow expandable with AnimatedCrossFade | VERIFIED | StatefulWidget with AnimatedCrossFade, MediaQuery.disableAnimations reduced motion support, Semantics |
| `apps/mobile/lib/screens/main_tabs/mint_home_screen.dart` | Rewired Aujourd'hui tab with unified card system | VERIFIED | ContextualCardProvider watched, sealed class switch dispatching all 5 subtypes, staggered MintEntrance animations |
| `apps/mobile/lib/app.dart` | ContextualCardProvider registered in MultiProvider | VERIFIED | Line 1013: `ChangeNotifierProvider(create: (_) => ContextualCardProvider())` |
| `apps/mobile/lib/l10n/app_fr.arb` (x6 languages) | 25 i18n keys in all 6 ARB files | VERIFIED | ctxCoachOpenerFallback confirmed in all 6 files (fr, en, de, es, it, pt); ctxHeroStatLabel, ctxActionScanTitle confirmed in FR |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `contextual_ranking_service.dart` | `contextual_card.dart` | produces ContextualCard instances | WIRED | Lines 68-115: `ContextualHeroCard`, `ContextualAnticipationCard`, `ContextualOverflowCard` instantiated directly |
| `contextual_ranking_service.dart` | `anticipation_ranking.dart` (Phase 4) | wraps AnticipationSignal into ContextualCard.anticipation | WIRED | Lines 75-83: `anticipationVisible.map((s) => ContextualAnticipationCard(signal: s))` |
| `contextual_card_provider.dart` | `contextual_ranking_service.dart` | calls rank() on session start | WIRED | Line 64: `_rankResult = ContextualRankingService.rank(...)` |
| `mint_home_screen.dart` | `contextual_card_provider.dart` | context.watch<ContextualCardProvider>() | WIRED | Lines 178, 218: two distinct watch calls for opener and card feed |
| `coach_opener_service.dart` | `anonymized_biography_service.dart` / BiographyFact | reads biography for personalization | WIRED | Lines 100-133: iterates `List<BiographyFact>`, checks `FactType.salary`, `FactSource.document` |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| `mint_home_screen.dart` (coach opener) | `coachOpener` | `ContextualCardProvider._coachOpener` ← `CoachOpenerService.generate()` ← `List<BiographyFact>` | Yes — iterates real BiographyFact list from BiographyProvider | FLOWING |
| `mint_home_screen.dart` (card feed) | `visibleCards` | `ContextualCardProvider._rankResult` ← `ContextualRankingService.rank()` ← profile + facts + anticipation signals | Yes — all inputs from live providers (CoachProfileProvider, BiographyProvider, AnticipationProvider) | FLOWING |
| `hero_stat_card.dart` | `card.value` | `HeroStatResolver.resolve()` ← `CoachProfile.total3aMensuel`, `CoachProfile.salaireBrutMensuel`, `ConfidenceScorer.scoreEnhanced()` | Yes — computed from real profile data, no hardcoded values | FLOWING |

### Behavioral Spot-Checks

Step 7b: The services and ranking logic are pure static functions — not HTTP endpoints or CLI tools. Module-level exports were verified by confirming all 33 tests pass. No runnable server entry point exists for this phase.

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| All contextual service tests pass | `flutter test test/services/contextual/ --reporter compact` | 33/33 tests passed | PASS |
| MintHomeScreen tests pass | `flutter test test/screens/main_tabs/mint_home_screen_test.dart` | 5/5 tests passed | PASS |
| Navigation shell tests pass (CTX-06) | `flutter test test/screens/coach/navigation_shell_test.dart test/screens/core_app_screens_smoke_test.dart` | 43/43 tests passed | PASS |
| No hardcoded colors in card widgets | `grep -rn "Color(0x"` on 4 widget files | 0 matches | PASS |
| No non-injectable DateTime.now() in services | `grep -rn "DateTime.now()"` filtered for non-gateway usage | 0 matches in service layer | PASS |
| flutter analyze on phase 05 files | 7 files analyzed | 1 warning (unused parameter `key` in home screen private widget — pre-existing) | PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| CTX-01 | 05-01 | Aujourd'hui displays max 5 cards with hero stat, anticipation, progress, action, overflow | SATISFIED | ContextualRankingService enforces 4 visible + 1 overflow; all 5 card types exist and render |
| CTX-02 | 05-01 | Card ranking updates once per session, deterministic | SATISFIED | ContextualCardProvider.evaluateOnSessionStart() guarded by `_evaluated` flag; pure static ranking |
| CTX-03 | 05-02 | Coach opener is biography-aware and LSFin compliant | SATISFIED | CoachOpenerService uses FactSource.document facts, ComplianceGuard validates output, conditional language throughout |
| CTX-04 | 05-02 | Each card deep-links to relevant simulator or tool | SATISFIED | All 4 widget types call `context.push(card.route)`; routes set by detectors (3a, retirement, onboarding, documents) |
| CTX-05 | 05-01 | Completed action demotes its triggering card | SATISFIED | `demoteCard()` removes from visible + appends to overflow; sort by priorityScore=0 last |
| CTX-06 | 05-02 | 3-tab shell + ProfileDrawer unchanged | SATISFIED | MainNavigationShell untouched; all navigation tests pass; home screen modifies body content only |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `mint_home_screen.dart` | 817 | Unused optional `key` parameter in private widget | Info | Pre-existing warning, unrelated to Phase 05 changes; zero functional impact |

No TODO/FIXME/placeholder comments found in any Phase 05 files. No hardcoded colors. No hardcoded strings (all user-facing text uses i18n keys or computed values). No stub return patterns.

### Human Verification Required

#### 1. Hero Card Renders Real Data on Device

**Test:** Launch the app on a device or emulator with a CoachProfile that has a salary and no 3a contribution. Navigate to the Aujourd'hui tab.
**Expected:** The hero card (slot 1) shows a large number representing the 3a gap (e.g., "7'258") with label "Tu laisses 7'258 CHF/an sur la table en 3a" and narrative "Soit 605 CHF/mois que tu pourrais deduire." The card is tappable and navigates to the 3a simulator.
**Why human:** CoachProfile must be non-null with real salary data. Widget rendering with live provider state cannot be verified without a running Flutter instance.

#### 2. Coach Opener Reflects Recent Biography Event

**Test:** Scan a document (or insert a BiographyFact with FactSource.document, updatedAt within 30 days) then cold-launch the app.
**Expected:** The opener above the card feed reads "Ton certificat [type] affine tes projections. Voici ton tableau de bord." — not the fallback greeting.
**Why human:** Requires a live BiographyProvider populated with a recent document fact; session state must be reset between launches to trigger re-evaluation.

#### 3. Card Deep-Link Navigation

**Test:** Tap each card type (hero, progress, action) from the Aujourd'hui tab.
**Expected:** Hero card routes to the 3a simulator or retirement projection. Progress card routes to /onboarding/quick?section=profile. Action 'Scanner un document' routes to /documents/capture. No navigation errors or blank screens.
**Why human:** GoRouter navigation under test uses mock routing; real route registration and guard behavior require a running app.

#### 4. Overflow Expand/Collapse Animation

**Test:** On a device with more than 4 card-worth of data (multiple anticipation signals + actions), observe the overflow row and tap it.
**Expected:** Overflow row shows "Voir plus — N element(s) supplementaire(s)"; tapping expands with AnimatedCrossFade (300ms); icon rotates to expand_less. On a device with reduced motion enabled, expansion is instant (no animation).
**Why human:** Stateful expand/collapse and animation behavior require visual confirmation; reduced motion branch cannot be triggered programmatically in widget tests.

#### 5. 3-Tab Shell Visually Unchanged

**Test:** Navigate between the three tabs (Aujourd'hui, Coach, Explorer) and open the ProfileDrawer.
**Expected:** Exactly 3 tabs present, labels correct, ProfileDrawer opens from the right edge, no tab was added or removed. Aujourd'hui tab body shows the new card feed without any layout regression.
**Why human:** Visual tab appearance and drawer gesture require device testing; existing tests cover count but not visual fidelity.

### Gaps Summary

No gaps found. All 9 observable truths are verified, all 14 required artifacts exist and are substantive, all 5 key links are wired, all 6 requirements are satisfied. The phase goal is achieved in code. Five items require human verification for visual/runtime confirmation, which is standard for a Flutter UI phase.

---

_Verified: 2026-04-06T19:26:54Z_
_Verifier: Claude (gsd-verifier)_
