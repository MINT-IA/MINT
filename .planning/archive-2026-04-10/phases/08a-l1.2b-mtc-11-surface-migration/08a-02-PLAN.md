---
phase: 08a-l1.2b-mtc-11-surface-migration
plan: 02
type: execute
wave: 2
depends_on: [08a-01]
files_modified:
  - apps/mobile/lib/widgets/home/confidence_score_card.dart
  - apps/mobile/lib/widgets/retirement/confidence_banner.dart
  - apps/mobile/lib/widgets/profile/trajectory_view.dart
  - apps/mobile/lib/widgets/profile/futur_projection_card.dart
  - apps/mobile/lib/widgets/coach/coach_briefing_card.dart
  - apps/mobile/lib/widgets/coach/retirement_hero_zone.dart
  - apps/mobile/lib/widgets/coach/indicatif_banner.dart
  - apps/mobile/lib/widgets/profile/narrative_header.dart
  - apps/mobile/lib/screens/coach/retirement_dashboard_screen.dart
  - apps/mobile/lib/screens/coach/cockpit_detail_screen.dart
  - apps/mobile/lib/widgets/coach/confidence_blocks_bar.dart
  - apps/mobile/lib/l10n/app_fr.arb
  - apps/mobile/lib/l10n/app_en.arb
  - apps/mobile/lib/l10n/app_de.arb
  - apps/mobile/lib/l10n/app_es.arb
  - apps/mobile/lib/l10n/app_it.arb
  - apps/mobile/lib/l10n/app_pt.arb
  - apps/mobile/test/widgets/trust/mtc_migration_smoke_test.dart
autonomous: false
requirements: [MTC-10, MTC-11, TRUST-02]
must_haves:
  truths:
    - "All 10 calculation surfaces render MintTrameConfiance when a non-null EnhancedConfidence is available"
    - "confidence_blocks_bar is refactored to DataBlockConfidenceBar and no longer claims to render projection trust"
    - "Every new or modified ARB key on the 11 surfaces passes the TRUST-02 sentence-subject rule (MINT-as-subject on negatives)"
    - "Each batch leaves flutter analyze at 0 errors and the existing test count does not regress"
    - "No surface re-implements _confidenceColor, the <70 threshold, or ±15% uncertainty band locally"
  artifacts:
    - path: apps/mobile/lib/widgets/home/confidence_score_card.dart
      provides: "MTC inline consumer, legacy painter removed"
    - path: apps/mobile/lib/widgets/coach/confidence_blocks_bar.dart
      provides: "DataBlockConfidenceBar sibling (extraction, not calculation)"
    - path: apps/mobile/test/widgets/trust/mtc_migration_smoke_test.dart
      provides: "runtime pump smoke test for each of the 10 MTC surfaces"
  key_links:
    - from: "each of the 10 MTC surfaces"
      to: apps/mobile/lib/widgets/trust/mint_trame_confiance.dart
      via: "direct import + .inline() or .detail() constructor"
      pattern: "MintTrameConfiance\\.(inline|detail|empty)"
    - from: each of the 10 MTC surfaces
      to: apps/mobile/lib/models/response_card.dart
      via: "reads card.confidence (introduced by Plan 08a-01)"
      pattern: "\\.confidence"
---

<objective>
Migrate the 11 ROADMAP surfaces to the new dual-system-free state. 10 of them consume `MintTrameConfiance` (per CONTEXT §D-01 table). The 11th (`confidence_blocks_bar.dart`) is refactored to a `DataBlockConfidenceBar` sibling per AUDIT-01 extraction carve-out. ARB content for every touched string is authored under the TRUST-02 sentence-subject rule.

Purpose: Kill the dual-system. Every confidence rendering site either speaks MTC or explicitly speaks extraction — no third category survives in the 11 files.
Output: 11 files migrated, ARB keys in 6 languages added/updated, runtime smoke tests proving the MTC actually paints, Julien A14 checkpoint at the end.
</objective>

<execution_context>
@/Users/julienbattaglia/Desktop/MINT/.claude/get-shit-done/workflows/execute-plan.md
</execution_context>

<context>
@.planning/phases/08a-l1.2b-mtc-11-surface-migration/08a-CONTEXT.md
@.planning/phases/08a-l1.2b-mtc-11-surface-migration/08a-01-PLAN.md
@.planning/phases/04-p4-mtc-component-s4-migration/04-CONTEXT.md
@docs/AUDIT-01-confidence-semantics.md
@docs/AUDIT_RETRAIT_S0_S5.md
@apps/mobile/lib/widgets/trust/mint_trame_confiance.dart
@apps/mobile/lib/models/response_card.dart
@apps/mobile/lib/services/financial_core/confidence_scorer.dart
@CLAUDE.md

<interfaces>
MintTrameConfiance public API (from Phase 4, file already exists):
  .inline({required EnhancedConfidence confidence, required BloomStrategy strategy, VoiceLevel? level})
  .detail({required EnhancedConfidence confidence, required BloomStrategy strategy, List<String> hypotheses = const []})
  .empty({required ConfidenceAxis missingAxis})
  .audio({...})  // not used in Phase 8a

BloomStrategy enum:
  firstAppearance | onlyIfTopOfList | never

Per-surface default strategy: see CONTEXT §D-01 table.
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1 (Batch A — Coach family): migrate 5 coach surfaces to MTC + refactor confidence_blocks_bar</name>
  <files>
    apps/mobile/lib/widgets/coach/coach_briefing_card.dart
    apps/mobile/lib/widgets/coach/indicatif_banner.dart
    apps/mobile/lib/widgets/coach/retirement_hero_zone.dart
    apps/mobile/lib/widgets/coach/confidence_blocks_bar.dart
    apps/mobile/lib/screens/coach/cockpit_detail_screen.dart
    apps/mobile/lib/l10n/app_fr.arb
    apps/mobile/lib/l10n/app_en.arb
    apps/mobile/lib/l10n/app_de.arb
    apps/mobile/lib/l10n/app_es.arb
    apps/mobile/lib/l10n/app_it.arb
    apps/mobile/lib/l10n/app_pt.arb
    apps/mobile/test/widgets/trust/mtc_migration_smoke_test.dart
  </files>
  <behavior>
    For each migrated coach surface, a pump test in mtc_migration_smoke_test.dart:
    - Test 1: With a non-null EnhancedConfidence, `find.byType(MintTrameConfiance)` returns ≥ 1 hit.
    - Test 2: With `confidence == null`, no MintTrameConfiance is rendered AND no legacy confidence widget is rendered (grep-style assertion via `find.byType(ConfidenceBanner)` etc. returns 0).
    - Test 3: Coach feed surfaces (coach_briefing_card) instantiate with `BloomStrategy.onlyIfTopOfList`; standalone surfaces (indicatif_banner, retirement_hero_zone, cockpit_detail_screen) instantiate with `BloomStrategy.firstAppearance`. Assert via a test helper that intercepts the strategy.
    - Test 4: confidence_blocks_bar is refactored to `DataBlockConfidenceBar` and its test asserts it does NOT import `mint_trame_confiance.dart` (it stays a sibling per AUDIT-01).
    - Test 5: Every new/modified ARB key used by these surfaces — if the string is a negative statement — has MINT as its subject (unit-level regex over the 6 ARB files touched).
  </behavior>
  <action>
    For each of the 5 coach surfaces:

    1. **coach_briefing_card.dart** — Replace the current confidence chip in the header with `MintTrameConfiance.inline(confidence: card.confidence!, strategy: BloomStrategy.onlyIfTopOfList)`. Wrap in `if (card.confidence != null)` — null = no MTC. Remove the local `_confidenceColor` or any `< 70` branching.

    2. **indicatif_banner.dart** — This entire widget is the legacy "mini gauge + indicatif label" surface per AUDIT-01 row 1. Delete the hand-rolled gauge painter. Replace the widget body with `MintTrameConfiance.inline(...)` using `BloomStrategy.firstAppearance`. The file stays (callers import it by name) but its body collapses to an MTC wrapper that takes an `EnhancedConfidence` and forwards it. Mark the class `@Deprecated('Use MintTrameConfiance.inline directly. Will be removed in Phase 11.')` so new code stops routing through it.

    3. **retirement_hero_zone.dart** — Per AUDIT-01 rows 2+3, this is the CANONICAL MTC surface. Remove `_buildConfidenceChip`, remove `_ConfidenceChipState`, remove the local `isApproximate = score < 70` check, remove the hard-coded `±15%` band string. Replace with `MintTrameConfiance.detail(confidence: heroConfidence, strategy: BloomStrategy.firstAppearance, hypotheses: heroHypotheses)`. The uncertainty band logic moves to MTC; the hero just hands over the EnhancedConfidence.

    4. **confidence_blocks_bar.dart** — Per CONTEXT §D-01 row 11 + D-06 special case: this is `extraction`, NOT `calculation`. Rename the public class `ConfidenceBlocksBar` → `DataBlockConfidenceBar` (keep a `@Deprecated` typedef alias for one phase). Do NOT import MintTrameConfiance. The file must stop matching the coverage gate's `ConfidenceBlocksBar(` pattern — only `DataBlockConfidenceBar(` instantiations remain.

    5. **cockpit_detail_screen.dart** — Replace the embedded confidence breakdown with `MintTrameConfiance.detail(confidence: state.enhancedConfidence, strategy: BloomStrategy.firstAppearance, hypotheses: state.hypotheses)`. Remove any local tier color helpers.

    For every string touched or added:
    - Add the key to all 6 ARB files (fr template first, then en, de, es, it, pt).
    - Negative statements use MINT as subject: "MINT ne voit pas encore assez de données pour s'engager sur ce chiffre." — never "Tu n'as pas renseigné…".
    - Run `flutter gen-l10n` after ARB changes.

    Write 5 smoke tests in `mtc_migration_smoke_test.dart` (create file) following the behavior spec. Use fake EnhancedConfidence fixtures from Plan 08a-01's confidence_scorer round-trip.

    Commit this batch as: `feat(p8a): migrate coach family (5 surfaces) to MintTrameConfiance`
  </action>
  <verify>
    <automated>cd apps/mobile && flutter gen-l10n && flutter analyze lib/widgets/coach lib/screens/coach lib/widgets/trust && flutter test test/widgets/trust/mtc_migration_smoke_test.dart</automated>
  </verify>
  <done>
    5 coach surfaces use MintTrameConfiance (or DataBlockConfidenceBar sibling for #4). Legacy helpers removed. 6 ARB files updated. flutter analyze 0 errors. Smoke tests green. Grep `_confidenceColor` in the 5 files returns 0 hits.
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 2 (Batch B — Profile family): migrate 3 profile surfaces to MTC</name>
  <files>
    apps/mobile/lib/widgets/profile/trajectory_view.dart
    apps/mobile/lib/widgets/profile/futur_projection_card.dart
    apps/mobile/lib/widgets/profile/narrative_header.dart
    apps/mobile/lib/l10n/app_fr.arb
    apps/mobile/lib/l10n/app_en.arb
    apps/mobile/lib/l10n/app_de.arb
    apps/mobile/lib/l10n/app_es.arb
    apps/mobile/lib/l10n/app_it.arb
    apps/mobile/lib/l10n/app_pt.arb
    apps/mobile/test/widgets/trust/mtc_migration_smoke_test.dart
  </files>
  <behavior>
    - Test 1: trajectory_view renders a `MintTrameConfiance.detail(...)` in its confidence cone area with `BloomStrategy.firstAppearance`.
    - Test 2: futur_projection_card renders `MintTrameConfiance.inline(...)` at the MUJI line-4 slot; null confidence → no MTC.
    - Test 3: narrative_header reads the weakest axis from the EnhancedConfidence and threads it through its opener copy via `oneLineConfidenceSummary()` (Phase 4 helper), NOT via a local tier-to-phrase map.
    - Test 4: Sentence-subject lint passes on all new keys.
  </behavior>
  <action>
    Per surface:

    1. **trajectory_view.dart** — Currently renders a confidence cone using local logic. Replace with `MintTrameConfiance.detail(confidence: trajectoryConfidence, strategy: BloomStrategy.firstAppearance)`. The cone chart itself stays (it's a chart, not a trust signal); only the trust-band header swaps to MTC.

    2. **futur_projection_card.dart** — Add `MintTrameConfiance.inline(...)` at the bottom of the card body (MUJI line 4). Receives `confidence` from the card's data model (extend the model's constructor to accept `EnhancedConfidence?` if not already present; null = no slot).

    3. **narrative_header.dart** — Currently reads a confidence int to pick an opener phrase. Replace the local mapping with `MintTrameConfiance.oneLineConfidenceSummary(confidence)` (Phase 4 helper — speaks the WEAKEST axis only). The header text below the summary stays.

    ARB: any opener variant strings must use MINT as subject on negatives ("MINT ne voit pas encore…"). Run `flutter gen-l10n`.

    Commit: `feat(p8a): migrate profile family (3 surfaces) to MintTrameConfiance`
  </action>
  <verify>
    <automated>cd apps/mobile && flutter gen-l10n && flutter analyze lib/widgets/profile lib/widgets/trust && flutter test test/widgets/trust/mtc_migration_smoke_test.dart</automated>
  </verify>
  <done>
    3 profile surfaces use MintTrameConfiance. narrative_header reads oneLineConfidenceSummary from MTC. flutter analyze 0 errors. Smoke tests green.
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 3 (Batch C — Home + Retirement family): migrate 3 final surfaces</name>
  <files>
    apps/mobile/lib/widgets/home/confidence_score_card.dart
    apps/mobile/lib/widgets/retirement/confidence_banner.dart
    apps/mobile/lib/screens/coach/retirement_dashboard_screen.dart
    apps/mobile/lib/l10n/app_fr.arb
    apps/mobile/lib/l10n/app_en.arb
    apps/mobile/lib/l10n/app_de.arb
    apps/mobile/lib/l10n/app_es.arb
    apps/mobile/lib/l10n/app_it.arb
    apps/mobile/lib/l10n/app_pt.arb
    apps/mobile/test/widgets/trust/mtc_migration_smoke_test.dart
  </files>
  <behavior>
    - Test 1: confidence_score_card renders MTC.detail with BloomStrategy.onlyIfTopOfList (Home is a feed context).
    - Test 2: confidence_banner is deprecated — its body becomes an MTC.inline wrapper with firstAppearance strategy; retained for call-site compat.
    - Test 3: retirement_dashboard_screen uses MTC.detail at the hero and does NOT re-implement local color tiers.
    - Test 4: After this batch, grep patterns from CONTEXT §D-07 return 0 hits across all 11 files.
  </behavior>
  <action>
    1. **confidence_score_card.dart** — Delete the standalone score card's hand-rolled visualization. Replace with `MintTrameConfiance.detail(confidence: scoreCardConfidence, strategy: BloomStrategy.onlyIfTopOfList, hypotheses: cardHypotheses)`. Card frame (title, padding, tap target) stays; only the trust visualization swaps.

    2. **confidence_banner.dart** (retirement) — Same pattern as `indicatif_banner` in Batch A: body collapses to `MintTrameConfiance.inline(..., strategy: BloomStrategy.firstAppearance)`. Class marked `@Deprecated`. The coverage gate will tolerate the deprecated class as long as no new call sites are added (Plan 08a-03 adds a stricter gate in a follow-up if needed).

    3. **retirement_dashboard_screen.dart** — Replace the dashboard hero's confidence surface with `MintTrameConfiance.detail(...)`. Pass hypotheses from dashboard state. Remove local tier coloring.

    Final batch includes a grep assertion in the smoke test file: it runs the CONTEXT §D-07 patterns across the 11 file list and asserts 0 hits (pre-empting the Plan 08a-03 CI gate). This is the "façade sans câblage" guard from CONTEXT §Pitfalls.

    Commit: `feat(p8a): migrate home + retirement family (3 surfaces) to MintTrameConfiance`
  </action>
  <verify>
    <automated>cd apps/mobile && flutter gen-l10n && flutter analyze lib/widgets/home lib/widgets/retirement lib/screens/coach/retirement_dashboard_screen.dart lib/widgets/trust && flutter test test/widgets/trust/mtc_migration_smoke_test.dart</automated>
  </verify>
  <done>
    3 final surfaces migrated. All 11 migration files pass the D-07 grep. flutter analyze 0 errors. Full smoke test suite green.
  </done>
</task>

<task type="checkpoint:human-verify" gate="blocking">
  <name>Task 4: Julien Galaxy A14 verify on Home + migrated feed</name>
  <what-built>
    11 surfaces migrated to MintTrameConfiance. Home feed and retirement dashboard now bloom MTC with the new BloomStrategy defaults. Per ROADMAP §Phase 8a Success Criterion 5, Julien manually runs a Galaxy A14 scroll + bloom check on the home surface.
  </what-built>
  <how-to-verify>
    1. Pull branch, `cd apps/mobile && flutter run -d <Galaxy A14 device id>` in profile mode.
    2. Launch app → Home. Observe: MTC blooms ONCE on the top card (onlyIfTopOfList), no bloom-storm on scroll.
    3. Scroll the feed up and down 3 full pages. Watch for: dropped frames (should be 0), stutter on MTC appearance (should be none), color-tier flicker (should be none).
    4. Open retirement dashboard (`cockpit_detail_screen`). Verify MTC.detail paints at the hero with the 4-axis trame, and the `±15%` uncertainty band appears as the MTC band (not a hand-rolled chip).
    5. Toggle system accessibility "Reduce animations". Re-open home. Verify bloom falls back to 50ms opacity-only.
    6. Open a coach briefing card with known-low confidence profile (use golden couple Lauren pre-onboarding fixture if available). Verify MTC.empty state renders with a MINT-as-subject copy ("MINT ne voit pas encore assez de données…") — no "Tu n'as pas…".
  </how-to-verify>
  <resume-signal>Type "A14 verified" or describe issues (per-surface)</resume-signal>
</task>

</tasks>

<verification>
- After each batch: `flutter analyze` 0 errors, `flutter test test/widgets/trust/mtc_migration_smoke_test.dart` green.
- After Batch C: D-07 grep returns 0 hits across the 11 files (self-test inside the smoke suite).
- After Task 4: Julien signs A14 checkpoint.
</verification>

<success_criteria>
All 11 surfaces per CONTEXT §D-01 migrated. The dual-system is dead inside Phase 8a scope. MTC is the only confidence renderer for calculation-confidence; extraction is the only renderer for extraction-confidence (via DataBlockConfidenceBar sibling). Every new ARB string passes TRUST-02. A14 smoke check signed.
</success_criteria>

<output>
After completion, create `.planning/phases/08a-l1.2b-mtc-11-surface-migration/08a-02-SUMMARY.md`.
</output>
