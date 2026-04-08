---
phase: quick-260406-ees
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - apps/mobile/lib/screens/main_tabs/mint_home_screen.dart
  - apps/mobile/lib/l10n/app_fr.arb
  - apps/mobile/lib/l10n/app_en.arb
  - apps/mobile/lib/l10n/app_de.arb
  - apps/mobile/lib/l10n/app_es.arb
  - apps/mobile/lib/l10n/app_it.arb
  - apps/mobile/lib/l10n/app_pt.arb
autonomous: true
requirements: [quick-260406-ees]
must_haves:
  truths:
    - "When an active CapSequence exists with >= 1 incomplete step, the home screen shows a journey steps card after the PlanRealityCard section"
    - "When no active CapSequence exists (no declared goal or all steps complete), no journey card is shown"
    - "Current step is highlighted and tappable (navigates to intentTag route)"
    - "Next upcoming step is visible but muted"
    - "Progress fraction (N/M) is displayed"
    - "All strings use i18n via AppLocalizations"
  artifacts:
    - path: "apps/mobile/lib/screens/main_tabs/mint_home_screen.dart"
      provides: "_JourneyStepsCard widget + integration in build()"
      contains: "_JourneyStepsCard"
  key_links:
    - from: "mint_home_screen.dart"
      to: "MintStateProvider"
      via: "context.watch<MintStateProvider>().state.capSequencePlan"
      pattern: "mintState\\.capSequencePlan"
---

<objective>
Add a compact CapSequence journey steps card to MintHomeScreen, positioned after the PlanRealityCard section (Section 1c). The card reads the already-computed `capSequencePlan` from `MintUserState` (populated by `MintStateEngine` from `CapMemoryStore` + `CapSequenceEngine`). Only shown when an active sequence exists with at least 1 incomplete step.

Purpose: Surface the user's multi-step financial journey progress on the home tab so they always know where they are and what to do next.
Output: Updated mint_home_screen.dart with inline `_JourneyStepsCard` widget + 6 ARB files with new i18n keys.
</objective>

<execution_context>
@/Users/julienbattaglia/Desktop/MINT/.claude/get-shit-done/workflows/execute-plan.md
@/Users/julienbattaglia/Desktop/MINT/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@apps/mobile/lib/screens/main_tabs/mint_home_screen.dart
@apps/mobile/lib/models/cap_sequence.dart
@apps/mobile/lib/widgets/pulse/cap_sequence_card.dart
@apps/mobile/lib/services/cap_memory_store.dart

<interfaces>
<!-- MintUserState already exposes everything needed -->

From apps/mobile/lib/models/mint_user_state.dart:
```dart
final CapSequence? capSequencePlan;
final String? activeGoalIntentTag;
```

From apps/mobile/lib/models/cap_sequence.dart:
```dart
class CapSequence {
  final String goalId;
  final List<CapStep> steps;
  final int completedCount;
  final int totalCount;
  final double progressPercent;
  bool get isComplete;
  CapStep? get currentStep;
  CapStep? get nextStep;
  bool get hasSteps;
}

class CapStep {
  final String id;
  final int order;
  final String titleKey;    // ARB key
  final String? descriptionKey;
  final CapStepStatus status;
  final String? intentTag;  // GoRouter route path
  final double? impactEstimate;
}

enum CapStepStatus { completed, current, upcoming, blocked }
```

From cap_sequence_card.dart — reuse the _resolveTitle pattern (switch on ARB key).
Already available ARB keys: capSequenceProgress(completed, total), capSequenceComplete, capSequenceCurrentStep.
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Add i18n keys for home journey section</name>
  <files>
    apps/mobile/lib/l10n/app_fr.arb
    apps/mobile/lib/l10n/app_en.arb
    apps/mobile/lib/l10n/app_de.arb
    apps/mobile/lib/l10n/app_es.arb
    apps/mobile/lib/l10n/app_it.arb
    apps/mobile/lib/l10n/app_pt.arb
  </files>
  <action>
Add the following 3 new i18n keys to ALL 6 ARB files (before the closing `}`):

1. `homeJourneyTitle` — Section header for the journey card.
   - fr: "Ton parcours"
   - en: "Your journey"
   - de: "Dein Weg"
   - es: "Tu recorrido"
   - it: "Il tuo percorso"
   - pt: "O teu percurso"

2. `homeJourneyNextStep` — Label for the "next step" CTA chip on the current step.
   - fr: "Prochaine\u00a0\u00e9tape"
   - en: "Next step"
   - de: "Naechster Schritt"
   - es: "Siguiente paso"
   - it: "Prossimo passo"
   - pt: "Proximo passo"

3. `homeJourneyUpcoming` — Label prefix for the upcoming step (muted).
   - fr: "Ensuite"
   - en: "Then"
   - de: "Danach"
   - es: "Luego"
   - it: "Poi"
   - pt: "Depois"

Add keys at END of file (before final `}`). No `@` metadata needed for simple strings (they are already inferred).

Then run `flutter gen-l10n` from `apps/mobile/` to regenerate the generated localization files.
  </action>
  <verify>
    <automated>cd /Users/julienbattaglia/Desktop/MINT/apps/mobile && flutter gen-l10n 2>&1 | tail -5</automated>
  </verify>
  <done>All 6 ARB files contain homeJourneyTitle, homeJourneyNextStep, homeJourneyUpcoming. gen-l10n succeeds.</done>
</task>

<task type="auto">
  <name>Task 2: Add _JourneyStepsCard widget and wire into MintHomeScreen</name>
  <files>apps/mobile/lib/screens/main_tabs/mint_home_screen.dart</files>
  <action>
**Part A: Create the `_JourneyStepsCard` private widget** at the bottom of mint_home_screen.dart (after existing private widgets like `_EmptySignalState`, before or after `_ChiffreVivantCard`).

Design — compact card showing current + next step only (NOT the full CapSequenceCard which is for Pulse):

```
  ┌─────────────────────────────────────────┐
  │  Ton parcours          3/10             │
  │  ────────────── progress bar ────────── │
  │                                         │
  │  ▶ Étape 3 — Avoir LPP      [Prochaine │
  │                                étape]   │
  │  ○ Ensuite : Étape 4 — Taux             │
  └─────────────────────────────────────────┘
```

Implementation details:
- `_JourneyStepsCard` is a `StatelessWidget` taking `CapSequence sequence` and optional `VoidCallback? onStepTap`.
- Uses `MintSurface` (import from `package:mint_mobile/widgets/premium/mint_surface.dart`) with `tone: MintSurfaceTone.blanc`, same as CapSequenceCard.
- Header row: `l.homeJourneyTitle` (left) + `"${sequence.completedCount}/${sequence.totalCount}"` (right, MintTextStyles.labelSmall, MintColors.textSecondary).
- Below header: `AnimatedProgressBar` (import from `package:mint_mobile/widgets/coach/animated_progress_bar.dart`) with `progress: sequence.progressPercent`, `color: MintColors.primary`.
- Current step row: play icon (same as CapSequenceCard _StatusIcon pattern — 18px circle MintColors.primary with play_arrow_rounded 12px white), resolved title via the same `_resolveTitle` switch pattern from CapSequenceCard (copy the switch block — it maps ARB key strings like `capStepRetirement01Title` to `l.capStepRetirement01Title`). Include ALL keys that CapSequenceCard resolves PLUS the FirstJob and NewJob keys: `capStepFirstJob01Title` through `capStepFirstJob05Title` and `capStepNewJob01Title` through `capStepNewJob05Title`. On the right: `l.homeJourneyNextStep` chip (same style as CapSequenceCard _CtaChip: GestureDetector, Container with MintColors.primary background, borderRadius 20, padding sm/xs, labelSmall white text). Tapping navigates via `context.go(step.intentTag!)` if intentTag is non-null.
- Next step row (if `sequence.nextStep` is non-null): empty circle icon (18px, MintColors.border), then `"${l.homeJourneyUpcoming}\u00a0:\u00a0"` prefix in MintTextStyles.bodySmall(color: MintColors.textMuted) + resolved title in same style.
- If sequence.isComplete, do NOT show this card (return SizedBox.shrink).
- If sequence.currentStep is null, do NOT show this card (return SizedBox.shrink).

**Part B: Wire into build() method.**

In the `build()` method of `_MintHomeScreenState`, insert a new section AFTER the PlanRealityCard section (Section 1c, around line 300 where the Builder for PlanRealityCard ends) and BEFORE Section 2 (Itineraire Alternatif).

Add a comment `// -- Section 1d: Journey Steps (active CapSequence) --` and insert:

```dart
Builder(
  builder: (ctx) {
    final seq = mintState.capSequencePlan;
    if (seq == null || seq.isComplete || seq.currentStep == null) {
      return const SizedBox.shrink();
    }
    // Only show when at least 1 step is incomplete
    final hasIncomplete = seq.steps.any(
      (s) => s.status != CapStepStatus.completed,
    );
    if (!hasIncomplete) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: MintSpacing.xl),
      child: MintEntrance(
        delay: const Duration(milliseconds: 200),
        child: _JourneyStepsCard(sequence: seq),
      ),
    );
  },
),
```

This requires importing `CapSequence` and `CapStepStatus` from `package:mint_mobile/models/cap_sequence.dart`. Add the import at the top of the file.

Also ensure `MintSurface` and `AnimatedProgressBar` are imported (MintSurface is already imported via mint_surface.dart; AnimatedProgressBar may need adding).

**Part C: The `_resolveTitle` method inside `_JourneyStepsCard`.**

Copy the same switch-based resolver from `cap_sequence_card.dart` but add the missing FirstJob and NewJob keys:

```dart
'capStepFirstJob01Title' => l.capStepFirstJob01Title,
'capStepFirstJob02Title' => l.capStepFirstJob02Title,
'capStepFirstJob03Title' => l.capStepFirstJob03Title,
'capStepFirstJob04Title' => l.capStepFirstJob04Title,
'capStepFirstJob05Title' => l.capStepFirstJob05Title,
'capStepNewJob01Title' => l.capStepNewJob01Title,
'capStepNewJob02Title' => l.capStepNewJob02Title,
'capStepNewJob03Title' => l.capStepNewJob03Title,
'capStepNewJob04Title' => l.capStepNewJob04Title,
'capStepNewJob05Title' => l.capStepNewJob05Title,
```

Check that these ARB keys exist in the codebase first. If any are missing from the generated localizations, use the fallback `_ => key` pattern (already present in CapSequenceCard).

Do NOT hardcode any user-facing strings. All text via `S.of(context)!`.
Do NOT use any color hex values. All colors via `MintColors.*`.
  </action>
  <verify>
    <automated>cd /Users/julienbattaglia/Desktop/MINT/apps/mobile && flutter analyze 2>&1 | tail -10</automated>
  </verify>
  <done>
- `flutter analyze` reports 0 errors.
- `_JourneyStepsCard` widget exists in mint_home_screen.dart.
- Section 1d is wired into the build() method after PlanRealityCard.
- Card only renders when capSequencePlan is non-null, not complete, and has a currentStep.
- Current step shows play icon + title + CTA chip.
- Next step shows circle icon + "Ensuite : title" (muted).
- All strings via i18n, all colors via MintColors.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| SharedPreferences -> UI | CapMemory data read from local storage displayed in UI |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-quick-01 | I (Information Disclosure) | _JourneyStepsCard | accept | Card shows only step titles (ARB keys) and progress count — no PII, no financial amounts displayed in this card |
| T-quick-02 | T (Tampering) | CapMemory | accept | Read-only consumption of already-computed state from MintStateProvider — no writes from this widget |
</threat_model>

<verification>
1. `flutter analyze` — 0 errors
2. `flutter gen-l10n` — succeeds without errors
3. Visual: When a CapSequence with incomplete steps exists, the card appears on the home screen after PlanRealityCard
4. Visual: When no sequence or all steps complete, no card shown
</verification>

<success_criteria>
- MintHomeScreen displays a compact journey steps card when an active CapSequence has >= 1 incomplete step
- Card shows progress header (title + fraction + bar), current step with CTA, and optional next step
- Card is hidden when no sequence exists or sequence is fully complete
- All strings are i18n-compliant (6 ARB files)
- `flutter analyze` passes with 0 errors
</success_criteria>

<output>
After completion, create `.planning/quick/260406-ees-surface-capsequence-journey-steps-on-min/260406-ees-SUMMARY.md`
</output>
