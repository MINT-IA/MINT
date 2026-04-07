# AUDIT-01 — Confidence Semantics Audit

**Phase:** 02-p0b-contracts-and-audits / Plan 02-05
**Status:** committed
**Date:** 2026-04-07
**Scope:** All confidence-rendering surfaces in `apps/mobile/lib/`. Read-only audit. No source code modified.

## Gate

> **Phase 4 (MTC component design) and Phase 8a (MTC migration scope) BOTH read this doc as input. No MTC work may start without this audit committed.** A confidence rendering site that is not classified here is by default treated as `untouched` until reclassified.

## Methodology

Grep patterns executed against `apps/mobile/lib/` (Dart sources only):

```
EnhancedConfidence | confidence_score | \.confidence\b | confidenceScore | ConfidenceScore
freshness | lastUpdated | extractedAt | stale | decay
```

Each hit was inspected to determine **what semantic** the rendering site is communicating to the user. Three categories are defined per CONTEXT.md §D-06:

| Category | Definition |
|---|---|
| `extraction` | "How sure was extraction about a data point at input time" — OCR confidence, manual entry quality, bank-feed certainty. |
| `freshness` | "How stale the stored data is" — decay factor, days since last update, refresh prompt. |
| `calculation` | "How sure a projection is" — `EnhancedConfidence` 4-axis output flowing through `confidence_scorer.dart`. |

Per-category dispositions per CONTEXT.md §D-06 and the anti-shame doctrine:

| Category | MTC decision | Rationale |
|---|---|---|
| `calculation` | **MTC absorbs** | This IS the 4-axis surface MTC is designed to express. Phase 4 builds the component; Phase 8a migrates the consumers. |
| `extraction` | **sibling component** | These render OCR/manual/bank confidence at data-input time, not projection time. Mixing them into MTC would conflate "did we read your salary slip correctly" with "do we trust the retirement projection". A sibling `ExtractionConfidenceChip` widget is the right home (Phase 4 spec scope; not in MTC). |
| `freshness` | **case-by-case** | If the hit is a "last updated N days ago" badge on a user-editable field → `untouched` (it's a data hygiene affordance, not a projection). If the hit is a decay factor INSIDE a projection → MTC absorbs (freshness is one of the 4 axes). |

`untouched` = the site stays as-is and is added to the DO-NOT-MIGRATE list.

## Full Hit Table

| # | file:line | widget / fn | what it renders | category | decision | notes |
|---|---|---|---|---|---|---|
| 1 | `lib/widgets/coach/indicatif_banner.dart:7-95` | `IndicatifBanner` | Banner shown when projection confidence < 70%. Mini gauge (0-100%) + "indicatif" label. | calculation | MTC absorbs | Top-of-card disclosure surface → becomes the MTC trust band header. |
| 2 | `lib/widgets/coach/retirement_hero_zone.dart:44-216` | `RetirementHeroZone._buildConfidenceChip` | Tappable confidence chip on the hero number, opens confidence dashboard. `isApproximate = score < 70`. ±15% uncertainty band rendered when approximate. | calculation | MTC absorbs | Canonical MTC surface. Drives the uncertainty band logic Phase 4 ports verbatim. |
| 3 | `lib/widgets/coach/retirement_hero_zone.dart:481-615` | `_ConfidenceChipState` | The chip painter (color tier + label tier from score). | calculation | MTC absorbs | Tier coloring is exactly what MTC normalizes — must NOT be reinvented per surface. |
| 4 | `lib/widgets/coach/confidence_blocks_bar.dart` (whole file) | `ConfidenceBlocksBar` | Per-data-block confidence pills row (revenu, LPP, 3a, …). | extraction | sibling component | These are completeness-of-input pills, not projection trust. They feed `ConfidenceScorer.scoreAsBlocs`. Belongs to a `DataBlockConfidenceBar` sibling. |
| 5 | `lib/widgets/coach/low_confidence_card.dart` (whole file) | `LowConfidenceCard` | Empty-state card shown when overall confidence < threshold; CTA to enrich data. | calculation | MTC absorbs | Becomes MTC's "low trust" empty state. |
| 6 | `lib/widgets/coach/coach_briefing_card.dart` | `CoachBriefingCard` (confidence chip in header) | Renders an MTC-style chip in the briefing header. | calculation | MTC absorbs | Listed in MTC-10 migration surfaces. |
| 7 | `lib/widgets/coach/progressive_dashboard_widget.dart:36-60` | `ProgressiveDashboardWidget` | `confidenceScore` (0-100 int) drives display depth (which sections are visible). | calculation | MTC absorbs | This is a CONSUMER of the score, not a renderer of a number. MTC must expose `combined: int` for back-compat (see DO-NOT-MIGRATE list). |
| 8 | `lib/widgets/coach/widget_renderer.dart:95-211` | `_renderConfidenceChip` | Renders backend `{intent, confidence, context_message}` payload as a chip with `${confidence}\u00a0%`. | calculation | MTC absorbs | Server-driven chip; MTC absorbs after CONTRACT-05 lands. |
| 9 | `lib/widgets/coach/plan_preview_card.dart:56-178` | `PlanPreviewCard` | `confidenceLevel` (0-100). Renders confidence bands when level < 70 via `l.planCard_confidenceBands(...)`. | calculation | MTC absorbs | Bands are uncertainty-axis output. |
| 10 | `lib/widgets/home/financial_plan_card.dart:11-323` | `FinancialPlanCard` (expanded detail) | "Voir le détail" expansion shows milestones + confidence bands + disclaimer. | calculation | MTC absorbs | Listed in MTC-10 (futur_projection_card analogue on Home). |
| 11 | `lib/widgets/profile/futur_projection_card.dart` (whole file) | `FuturProjectionCard` | Projection card with embedded MTC-style trust footer. | calculation | MTC absorbs | Explicitly in MTC-10. |
| 12 | `lib/widgets/profile/trajectory_view.dart` (whole file) | `TrajectoryView` | Trajectory chart with confidence cone. | calculation | MTC absorbs | Explicitly in MTC-10. |
| 13 | `lib/widgets/profile/narrative_header.dart` (whole file) | `NarrativeHeader` | Narrative header reading confidence to phrase its opener. | calculation | MTC absorbs | Explicitly in MTC-10. |
| 14 | `lib/widgets/home/confidence_score_card.dart` (whole file) | `ConfidenceScoreCard` | Standalone card displaying the score breakdown. | calculation | MTC absorbs | Explicitly in MTC-10. |
| 15 | `lib/widgets/retirement/confidence_banner.dart` (whole file) | `ConfidenceBanner` | Retirement-specific confidence banner. | calculation | MTC absorbs | Explicitly in MTC-10. |
| 16 | `lib/widgets/confidence_breakdown_card.dart:4-37` | `ConfidenceBreakdownCard` | Compact wrapper around `ConfidenceBreakdownChart`. | calculation | MTC absorbs | The card is a thin frame; the chart logic is the canonical MTC visualisation. |
| 17 | `lib/widgets/confidence/confidence_breakdown_chart.dart:5-11` | `ConfidenceBreakdownChart` | Horizontal 3-axis (completeness / accuracy / freshness) breakdown. | calculation | MTC absorbs | The chart already encodes 3 of the 4 MTC axes; Phase 4 adds `understanding`. |
| 18 | `lib/widgets/precision/smart_default_indicator.dart:19-263` | `SmartDefaultIndicator` | Chip showing "Fiabilité : N %" for a smart-defaulted field. | extraction | sibling component | This is per-field "how sure are we about this default" — not a projection. Belongs to `ExtractionConfidenceChip` sibling. |
| 19 | `lib/widgets/premium/mint_ligne.dart:15-131` | `MintLigne` | Trajectory line that goes dashed when `confidence < 0.50`. | calculation | MTC absorbs | The dashed-vs-solid encoding is the canonical visual MTC must own. |
| 20 | `lib/widgets/coach/data_quality_card.dart` | `DataQualityCard` | Renders freshness + completeness pills. | freshness | sibling component | Data hygiene surface, not projection. Stays as a `DataHygieneCard` sibling. |
| 21 | `lib/widgets/coach/smart_shortcuts.dart` | `SmartShortcuts` (confidence ref) | Reads confidence to gate which shortcuts surface. | calculation | untouched (consumer) | Gate consumer — adds to DO-NOT-MIGRATE list. |
| 22 | `lib/widgets/biography/fact_card.dart` | `FactCard` | Per-fact freshness badge ("mis à jour il y a N jours"). | freshness | untouched | User-editable field hygiene — keep as-is. |
| 23 | `lib/widgets/onboarding/premier_eclairage_card.dart:110` | `_PremierEclairageCardState.build` | Reads `confidenceMode == 'pedagogical'` to adapt copy. | calculation | untouched (consumer) | Reads enum, not score — gate consumer. |
| 24 | `lib/widgets/profile/futur_drawer_content.dart` | `FuturDrawerContent` | Renders sub-surfaces of the futur drawer; embeds MTC chip. | calculation | MTC absorbs | Phase 8a migration surface. |
| 25 | `lib/screens/coach/cockpit_detail_screen.dart` | `CockpitDetailScreen` | Cockpit detail with embedded confidence breakdown. | calculation | MTC absorbs | Explicitly in MTC-10. |
| 26 | `lib/screens/coach/retirement_dashboard_screen.dart` | `RetirementDashboardScreen` | Full retirement dashboard with MTC surface. | calculation | MTC absorbs | Explicitly in MTC-10. |
| 27 | `lib/screens/confidence/confidence_dashboard_screen.dart:29-579` | `ConfidenceDashboardScreen` | Full-screen breakdown: gauge, level label (excellent/good/fair/improve/insufficient), 3-axis chart, gates, enrichment prompts, sources. | calculation | MTC absorbs | Becomes the MTC "deep dive" route. The level label scale moves from L5 ordinal to MTC tier names in Phase 4. |
| 28 | `lib/screens/profile/financial_summary_screen.dart:125-167` | `_buildConfidenceSection` | Computes `confidence = (knownCount / 7 * 100)` and renders a `MintConfidenceNotice` with boost percent. | extraction | sibling component | This is a hand-rolled completeness gauge over 7 input fields. Belongs to `DataCompletenessIndicator` sibling — must NOT be wired through MTC because the math is unrelated to `EnhancedConfidence`. |
| 29 | `lib/screens/onboarding/data_block_enrichment_screen.dart:11-195` | `DataBlockEnrichmentScreen` | Imports `ConfidenceScorer`, calls `scoreAsBlocs(profile)` and `score(profile)`, surfaces relevant prompts. | extraction | sibling component | Onboarding enrichment loop — feeds the input pipeline, not projection display. |
| 30 | `lib/screens/onboarding/instant_premier_eclairage_screen.dart:21-333` | `InstantPremierEclairageScreen` | Confidence badge in the premier éclairage card; `instantPremierEclairageConfidence` ARB key. | calculation | MTC absorbs | First MTC moment in the user journey — Phase 4 makes this the canonical "low-data MTC" preset. |
| 31 | `lib/screens/onboarding/premier_eclairage_screen.dart:15-407` | `PremierEclairageScreen` | `MintConfidenceNotice` with `premierEclairageConfidenceSimple(...)` message. | calculation | MTC absorbs | Same surface, second pass. |
| 32 | `lib/screens/arbitrage/arbitrage_bilan_screen.dart:310-357` | `ArbitrageBilanScreen` | Per-item confidence pill `${item.confidenceScore.round()}%` colored via `_confidenceColor`. | calculation | MTC absorbs | Color tiering must come from MTC tokens, not local `_confidenceColor`. |
| 33 | `lib/screens/arbitrage/allocation_annuelle_screen.dart:202-210` | `AllocationAnnuelleScreen` | Passes `_result.confidenceScore` to `ConfidenceBanner` and `MintLigne(confidence: ...)`. | calculation | MTC absorbs | Wires the same banner — migrates with the banner. |
| 34 | `lib/screens/arbitrage/location_vs_propriete_screen.dart:191-199` | `LocationVsProprieteScreen` | Same pattern as above. | calculation | MTC absorbs | Same as #33. |
| 35 | `lib/screens/arbitrage/rente_vs_capital_screen.dart:535-1117` | `RenteVsCapitalScreen` | Multiple sites: confidence banner, line dashing, "gratification" copy, simulator slider. | calculation | MTC absorbs | The "gratification" line at L969 renders a tier label — must read MTC tier, not local mapping. |
| 36 | `lib/screens/document_scan/document_scan_screen.dart:250-678` | `DocumentScanScreen` | `docScanConfidencePoints(_selectedType.confidenceImpact)`, parses per-field `confidence` from extraction response. | extraction | sibling component | OCR confidence → `ExtractionConfidenceChip`. Never flows through MTC. |
| 37 | `lib/screens/document_scan/extraction_review_screen.dart` | `ExtractionReviewScreen` | Per-extracted-field confidence indicator with edit affordance. | extraction | sibling component | Same as #36. |
| 38 | `lib/screens/profile/privacy_control_screen.dart:16` | `PrivacyControlScreen` | "Source, date, and freshness of each fact." | freshness | untouched | Data hygiene + privacy surface; no projection. |
| 39 | `lib/services/biography/freshness_decay_service.dart` (whole file) | `FreshnessDecayService` | Computes the freshness decay factor consumed by `confidence_scorer`. | freshness | MTC absorbs (as input) | This is the SOURCE of the freshness axis inside MTC. The service stays untouched; only its consumer (the scorer → MTC) changes. |
| 40 | `lib/services/financial_core/confidence_scorer.dart` (whole file) | `ConfidenceScorer` | The `EnhancedConfidence` 4-axis computation: completeness × accuracy × freshness × understanding. Returns prompts and combined int. | calculation | MTC absorbs (as input) | This is the engine. MTC is its renderer. The engine MUST keep emitting `combined: int` for the 7 logic-gate consumers in DO-NOT-MIGRATE. |
| 41 | `lib/services/confidence/enhanced_confidence_service.dart` | `EnhancedConfidenceService` | Wraps the scorer with caching + evolution tracking. | calculation | MTC absorbs (as input) | Same as #40. |
| 42 | `lib/services/coach/precomputed_insights_service.dart` (confidence refs) | `PrecomputedInsightsService` | Reads confidence to choose which insight to surface. | calculation | untouched (consumer) | Gate consumer — DO-NOT-MIGRATE. |

> **Total classified hits: 42** (above the ROADMAP estimate of ~40, ≥ 20 minimum required by the plan).

## Per-Category Decisions

### `calculation-confidence` — MTC absorbs

**Decision:** MTC absorbs every site classified as `calculation` in the table above (rows 1-3, 5-17, 19, 24-27, 30-35, 40-41 — 32 sites).

**Rationale:** These are exactly the 4-axis `EnhancedConfidence` surface MTC is designed to render: completeness × accuracy × freshness × understanding (geometric mean), with tier coloring, uncertainty bands, and the "indicatif" disclosure when below threshold. Each site today reinvents one or more of:

- the tier colour mapping (`_confidenceColor` appears at least 3 times),
- the threshold logic (`< 70` appears at least 5 times with three different copy variants),
- the uncertainty band geometry (`±15%` hard-coded in `retirement_hero_zone.dart`).

Phase 4 builds **one** `MintTrustChip` (and its `MintTrustBand` peer) that absorbs all of this. Phase 8a then migrates each site to the new component, preserving the existing `EnhancedConfidence` engine output (no math change). The migration is purely a renderer swap; the scorer file stays untouched as the source axis.

**Engine boundary:** `confidence_scorer.dart` and `enhanced_confidence_service.dart` are SOURCES, not RENDERERS. They are listed under `MTC absorbs (as input)` because Phase 4 reads their output schema, but their files are not edited by the migration. Any change to the engine (adding a 5th axis, recalibrating the geometric mean) is out of Phase 8a scope and requires its own ADR.

### `extraction-confidence` — sibling component (NOT MTC)

**Decision:** Build a separate `ExtractionConfidenceChip` widget family (Phase 4 spec scope, NOT in the MTC component itself). Sites in rows 4, 18, 28, 29, 36, 37 (6 sites) migrate to the sibling, not to MTC.

**Rationale:** Mixing extraction confidence into MTC would conflate two unrelated questions for the user:

1. *"Did we read your salary slip correctly?"* → extraction (per-field, OCR/manual/bank source).
2. *"Do we trust the projection that says you'll have CHF 8'500/month at 65?"* → calculation (4-axis, 30-year horizon, archetype-aware).

These have different math, different remediation paths (re-scan vs add data), and different anti-shame implications (a low extraction score is a tooling problem; a low calculation score is a "we need more from you" prompt). Phase 4 builds both surfaces with shared design tokens but separate components and separate copy. The sibling is OUT of MTC migration scope and is tracked under `EXTRACTION-CHIP` (Phase 4 sub-deliverable, no REQ yet — to be added if Phase 4 audit confirms scope).

### `freshness` — case-by-case

**Decision:** Of the 4 freshness hits (rows 20, 22, 38, 39), 3 stay `untouched` and 1 is `MTC absorbs (as input)`:

- Row 39 `freshness_decay_service.dart` is the SOURCE of the freshness axis inside `EnhancedConfidence`. It is not a renderer at all; MTC absorbs it transparently because the scorer already consumes it.
- Rows 20, 22, 38 (`DataQualityCard`, `FactCard`, `PrivacyControlScreen`) are user-facing **data hygiene** surfaces — "this fact was updated 47 days ago", "review your data sources" — and are **not** projection trust signals. Rendering them through MTC would imply the projection itself is stale, which is wrong: the projection's freshness axis is already encoded inside the calculation score. These three stay as a separate `DataHygieneCard` family (already exists, no migration needed).

This split honours the anti-shame doctrine: data hygiene affordances stay calm and matter-of-fact ("voici quand on en a parlé pour la dernière fois"), while projection trust signals carry the MTC tonal contract ("voici à quel point on s'engage sur ce chiffre").

## DO-NOT-MIGRATE List (Logic-Gate Consumers)

Per MTC-11 (REQUIREMENTS.md), these 7 consumers read `EnhancedConfidence.combined` as an `int` only. They never render a chip, badge, banner, or visualisation. They MUST stay untouched in Phase 8a, and the MTC engine output MUST keep emitting `combined: int` for back-compat.

| # | file:line | reads | use |
|---|---|---|---|
| 1 | `lib/widgets/coach/progressive_dashboard_widget.dart:36-60` | `confidenceScore` int | drives `_levelFromScore` to gate which dashboard sections render |
| 2 | `lib/widgets/coach/smart_shortcuts.dart` | `confidence` ref | gates which shortcuts surface |
| 3 | `lib/widgets/onboarding/premier_eclairage_card.dart:110` | `confidenceMode` enum | branches between pedagogical and standard copy |
| 4 | `lib/services/coach/precomputed_insights_service.dart` | `confidence` ref | chooses which insight to surface |
| 5 | `lib/services/cap_engine.dart` | `confidence_score` ref | adjusts cap-engine recommendation thresholds |
| 6 | `lib/services/coach/coach_orchestrator.dart` | `confidence_score` ref | gates which coach mode is allowed |
| 7 | `lib/services/financial_core/coach_reasoner.dart` | `confidence` ref | adjusts reasoning verbosity |

> **Contract for Phase 8a:** the MTC component MUST NOT replace these reads. Any PR that touches a file in this list and is not explicitly authorized by Phase 8a sub-plan is rejected.

## Open Questions (escalated to orchestrator)

1. **`errorAaa` borderline contrast** is documented in CONTEXT.md §6 AAA Tokens. It is unrelated to AUDIT-01 but worth flagging cross-audit: if Phase 4 uses `errorAaa` for a low-trust MTC chip on a `craie` background, the contrast unit test from Plan 02-02 must be re-run on that exact pair.
2. **`confidenceMode` enum** (row 23) carries a `pedagogical` vs `standard` distinction that is **not** in the `EnhancedConfidence` schema today. Phase 4 must decide whether MTC exposes this branch or whether it stays a separate prop. Default: stays separate.
3. **`ConfidenceScorer.scoreAsBlocs`** (row 29) returns a per-block list that does not match the 4-axis MTC schema. The sibling `DataCompletenessIndicator` consumes it directly. No translation layer needed.
