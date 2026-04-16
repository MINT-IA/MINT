---
phase: quick-260406-ees
plan: "01"
subsystem: flutter-home
tags: [cap-sequence, home-screen, i18n, journey-steps]
dependency_graph:
  requires: [MintStateProvider.capSequencePlan, CapSequence model, CapMemoryStore]
  provides: [_JourneyStepsCard widget, Section 1d on MintHomeScreen]
  affects: [apps/mobile/lib/screens/main_tabs/mint_home_screen.dart]
tech_stack:
  added: []
  patterns: [MintSurface blanc, AnimatedProgressBar, MintEntrance animation, switch-based ARB key resolver]
key_files:
  created: []
  modified:
    - apps/mobile/lib/screens/main_tabs/mint_home_screen.dart
    - apps/mobile/lib/l10n/app_fr.arb
    - apps/mobile/lib/l10n/app_en.arb
    - apps/mobile/lib/l10n/app_de.arb
    - apps/mobile/lib/l10n/app_es.arb
    - apps/mobile/lib/l10n/app_it.arb
    - apps/mobile/lib/l10n/app_pt.arb
decisions:
  - Used MintSurface blanc + AnimatedProgressBar consistent with CapSequenceCard from Pulse tab
  - Resolved ARB keys via switch pattern copied from cap_sequence_card.dart, extended with FirstJob/NewJob keys
  - Used MintEntrance with 200ms delay for entrance animation consistent with ConfidenceScoreCard
metrics:
  duration: ~10 minutes
  completed_date: "2026-04-06"
---

# Phase quick-260406-ees Plan 01: Surface CapSequence Journey Steps on MintHomeScreen Summary

**One-liner:** Compact journey steps card surfacing active CapSequence progress (current step + next step) on the home tab, using MintSurface blanc + AnimatedProgressBar + switch-based ARB key resolver covering 5 goal types.

## Tasks Completed

| # | Task | Commit | Files |
|---|------|--------|-------|
| 1 | Add i18n keys for home journey section | 8bc287a7 | 6 ARB files + 7 generated localizations |
| 2 | Add _JourneyStepsCard widget and wire into MintHomeScreen | f2b3c4e6 | mint_home_screen.dart (+235 lines) |

## What Was Built

### _JourneyStepsCard widget (`mint_home_screen.dart`)
- Private `StatelessWidget` at bottom of file (line ~1321)
- Takes `CapSequence sequence` parameter
- Returns `SizedBox.shrink()` when sequence is complete or has no current step
- Header row: `l.homeJourneyTitle` (left) + `completedCount/totalCount` fraction (right)
- `AnimatedProgressBar` with `sequence.progressPercent` and `MintColors.primary`
- Current step row: 18px primary circle + play_arrow_rounded 12px white + resolved title + CTA chip
- CTA chip navigates via `context.go(step.intentTag!)` when intentTag is non-null
- Next step row (optional): 18px border circle + `l.homeJourneyUpcoming + " : " + resolved title` (muted)
- `_resolveTitle` switch covers Retirement (10), Budget (6), Housing (7), FirstJob (5), NewJob (5) = 33 ARB keys + fallback

### Section 1d in `build()` method
- Builder inserted after PlanRealityCard (Section 1c), before Section 2
- Guard conditions: `seq == null || seq.isComplete || seq.currentStep == null` → shrink
- Secondary guard: `seq.steps.any(s => s.status != completed)` → at least 1 incomplete
- `MintEntrance` wrapper with 200ms delay for entrance animation

### i18n (6 ARB files)
- `homeJourneyTitle`: "Ton parcours" / "Your journey" / "Dein Weg" / "Tu recorrido" / "Il tuo percorso" / "O teu percurso"
- `homeJourneyNextStep`: "Prochaine\u00a0étape" / "Next step" / "Naechster Schritt" / "Siguiente paso" / "Prossimo passo" / "Proximo passo"
- `homeJourneyUpcoming`: "Ensuite" / "Then" / "Danach" / "Luego" / "Poi" / "Depois"

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

None. Widget reads live `capSequencePlan` from `MintStateProvider` which is populated by `MintStateEngine` from `CapMemoryStore` + `CapSequenceEngine`.

## Threat Flags

None. Card is read-only, shows only step titles (ARB keys) and progress count. No PII, no financial amounts.

## Self-Check: PASSED

- Commits 8bc287a7 and f2b3c4e6 verified in git log
- All 6 ARB files contain `homeJourneyTitle` key (1 match each)
- `_JourneyStepsCard` class defined at line 1321 of mint_home_screen.dart
- Section 1d wired at line 322 of mint_home_screen.dart
- `flutter analyze` reports 0 errors in mint_home_screen.dart (pre-existing test file errors unrelated to this plan)
- `flutter gen-l10n` succeeded without errors
