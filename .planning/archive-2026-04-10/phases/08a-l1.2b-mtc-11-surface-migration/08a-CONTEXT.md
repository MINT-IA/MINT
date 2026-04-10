# Phase 8a — L1.2b MTC 11-Surface Migration — CONTEXT

**Phase**: 08a-l1.2b-mtc-11-surface-migration
**Branch**: feature/v2.2-p0a-code-unblockers
**Depends on**: Phase 2 (AUDIT-01), Phase 3 (DELETE list), Phase 4 (MTC component shipped on S4)
**Requirements**: MTC-10, MTC-11, MTC-12, TRUST-02

## Objective

Kill the dual-system. Migrate the 11 remaining `calculation`-confidence rendering surfaces (per `docs/AUDIT-01-confidence-semantics.md`) to consume `MintTrameConfiance` (MTC) — the component shipped in Phase 4. Finish what Phase 4 deferred via D-07 null-fallback: extend `ResponseCard` (and the backend response schema) to carry `EnhancedConfidence?`, then flip the live wiring at every consumer.

This is the biggest renderer-swap phase of v2.2. No math change. No engine change. Pure consumer migration plus a coverage gate that prevents silent regression and an ARB lint that enforces TRUST-02 sentence-subject grammar on every touched string.

## Source-of-truth inputs

- `docs/AUDIT-01-confidence-semantics.md` — 42 hits classified. The 11 migration targets are the `calculation` sites listed in ROADMAP §Phase 8a Success Criterion 1, which is the canonical extraction of the audit's MTC-absorbs verdicts. The 7 DO-NOT-MIGRATE consumers (logic-gate readers of `combined: int`) are listed verbatim in the audit §DO-NOT-MIGRATE.
- `docs/AUDIT_RETRAIT_S0_S5.md` — Phase 3 DELETE list. Each migrated surface that overlaps S0-S5 must remove its DELETE-flagged elements in the same PR (no surface touched without honoring the audit).
- `.planning/phases/04-p4-mtc-component-s4-migration/04-CONTEXT.md` — D-01 (`MintTrameConfiance` is the locked class name; `MintTrustChip` from AUDIT-01 narration is rejected) and D-07 (S4 migration is null-fallback: caller passes `confidence: response.confidence` when available, else slot is hidden). Phase 8a flips that null fallback at every consumer.
- `apps/mobile/lib/widgets/trust/mint_trame_confiance.dart` — the component. Public API: `.inline()`, `.detail()`, `.audio()`, `.empty(missingAxis:)`. Caller resolves voice level upstream.
- `apps/mobile/lib/services/financial_core/confidence_scorer.dart` — engine. Untouched. Source of `EnhancedConfidence` (4 axes + combined int + enrichment prompts).
- `apps/mobile/lib/models/response_card.dart` — currently has NO `confidence` field. Phase 8a adds it (Plan 08a-01).

---

## Decisions (LOCKED)

### D-01 — The 11 migration targets (LOCKED)

Per ROADMAP §Phase 8a Success Criterion 1, the migration set is exactly these 11 surfaces. They map 1:1 to AUDIT-01 `calculation` rows that are NOT in the DO-NOT-MIGRATE list, NOT engine sources (`confidence_scorer.dart`, `enhanced_confidence_service.dart`, `freshness_decay_service.dart` stay untouched as inputs), and NOT already migrated by Phase 4 (S4 `response_card_widget.dart`).

| # | Surface (file) | AUDIT-01 row(s) | Family | Default `BloomStrategy` |
|---|---|---|---|---|
| 1 | `lib/widgets/home/confidence_score_card.dart` | 14 | Home (feed) | `onlyIfTopOfList` |
| 2 | `lib/widgets/retirement/confidence_banner.dart` | 15 | Retirement (standalone banner) | `firstAppearance` |
| 3 | `lib/widgets/profile/trajectory_view.dart` | 12 | Profile (chart) | `firstAppearance` |
| 4 | `lib/widgets/profile/futur_projection_card.dart` | 11 | Profile (card detail) | `firstAppearance` |
| 5 | `lib/widgets/coach/coach_briefing_card.dart` | 6 | Coach (feed item) | `onlyIfTopOfList` |
| 6 | `lib/widgets/coach/retirement_hero_zone.dart` | 2, 3 | Coach (hero) | `firstAppearance` |
| 7 | `lib/widgets/coach/indicatif_banner.dart` | 1 | Coach (top-of-card disclosure) | `firstAppearance` |
| 8 | `lib/widgets/profile/narrative_header.dart` | 13 | Profile (header) | `firstAppearance` |
| 9 | `lib/screens/coach/retirement_dashboard_screen.dart` | 26 | Screen | `firstAppearance` |
| 10 | `lib/screens/coach/cockpit_detail_screen.dart` | 25 | Screen | `firstAppearance` |
| 11 | `lib/widgets/coach/confidence_blocks_bar.dart` | 4 | **Special — see D-06** | n/a (sibling, not MTC) |

**Note on row 4 (`confidence_blocks_bar`):** AUDIT-01 classifies this as `extraction → sibling component` (the bar renders per-data-block input completeness, not projection trust). However, ROADMAP §Phase 8a Success Criterion 1 lists it explicitly in the 11-surface set. We resolve the conflict per D-06 below: in Phase 8a we *touch* this file (rename, deprecate the legacy renderer in favor of a `DataBlockConfidenceBar` sibling, and pass through the coverage gate exemption) but we do NOT route it through MTC. It is migration target #11 in the sense that the dual-system dies on this file too — just into a sibling, not into MTC.

**Surfaces NOT in the 11** (and their disposition):
- `response_card_widget.dart` — already done in Phase 4 (Plan 04-02).
- `confidence_dashboard_screen.dart`, `confidence_breakdown_card.dart`, `confidence_breakdown_chart.dart`, `mint_ligne.dart`, `low_confidence_card.dart`, `widget_renderer.dart`, `plan_preview_card.dart`, `financial_plan_card.dart`, `futur_drawer_content.dart`, the 4 arbitrage screens, `instant_premier_eclairage_screen.dart`, `premier_eclairage_screen.dart` — these are AUDIT-01 calculation sites that are NOT in the 11. They are **deferred to a Phase 8a follow-up sweep (Plan 08a-02 §Stretch)** OR are absorbed transitively because they wrap one of the 11 (e.g. `confidence_breakdown_card` wraps the chart which is consumed by `confidence_score_card`). The coverage gate (Plan 08a-03) lights up these files automatically — if the executor finds a transitive absorption is incomplete, it must either complete it inline OR add the file to a documented `MIGRATION_RESIDUE_8a.md` follow-up list. **Silent skipping is forbidden.**
- The 7 DO-NOT-MIGRATE logic-gate consumers from AUDIT-01 §DO-NOT-MIGRATE — never touched in Phase 8a.

### D-02 — Coverage gate authoritative target list = ROADMAP 11

The CI lint (`tools/checks/no_legacy_confidence_render.py`, Plan 08a-03) runs grep patterns (D-07 below) across `apps/mobile/lib/`. The 11 ROADMAP surfaces MUST go to zero hits. The DO-NOT-MIGRATE 7 are exempted by an in-script allowlist with file-path match (not regex of the line — we exempt the file, not the pattern). Any other hit is a build failure with a message pointing the executor to either migrate the file OR add it to `MIGRATION_RESIDUE_8a.md` with a justified reason and an open ticket reference.

### D-03 — `ResponseCard.confidence` extension (mobile model)

Add to `apps/mobile/lib/models/response_card.dart`:

```dart
/// 4-axis confidence for projection-shaped cards. Null = chat reply / education / non-projection.
final EnhancedConfidence? confidence;
```

- Constructor: optional named, defaults to `null` (back-compat with all existing call sites and Phase 4 S4 null-fallback).
- `toJson()`: emits `'confidence': confidence!.toJson()` only when non-null (no key when null — keeps payloads clean and back-compat with backend versions that don't emit it yet).
- `fromJson()`: tolerant — `json['confidence'] == null` → `null`.
- Import: `package:mint_mobile/services/financial_core/confidence_scorer.dart` (the `EnhancedConfidence` source). NO new file. NO new model. NO copy.

This finishes Phase 4 D-07: the field exists, every consumer that builds a `ResponseCard` from a projection answer passes it, MTC at the render site reads it.

### D-04 — Backend response schema mirror

Backend Pydantic schema for response cards (path: `services/backend/app/schemas/response_card.py` if it exists; otherwise the closest analogue under `services/backend/app/schemas/`) gets a parallel optional field:

```python
confidence: Optional[EnhancedConfidence] = None
```

with the same null-default + camelCase alias generation already in place. The backend `EnhancedConfidence` Pydantic class either already exists (check `services/backend/app/schemas/confidence.py` or equivalent) or is a new minimal mirror — see D-05 for the exact wire shape. **The backend is the source of truth for the wire format**; the mobile `EnhancedConfidence.fromJson` must accept exactly what the backend emits.

OpenAPI regen + SOT.md update if any contract drift is introduced. Plan 08a-01 owns this.

### D-05 — `EnhancedConfidence` wire format (LOCKED — full 4-axis)

Wire shape:

```json
{
  "completeness": 0.72,
  "accuracy": 0.85,
  "freshness": 0.91,
  "understanding": 0.60,
  "combined": 76,
  "weakestAxis": "understanding",
  "enrichmentPrompts": [
    { "axis": "understanding", "label": "Faire la session coach 'lire un certificat LPP'", "deepLink": "/coach/literacy/lpp" }
  ]
}
```

**Rationale for full 4-axis (not just `combined`):**
1. MTC `.detail()` constructor consumes the per-axis breakdown to render the 4-segment trame. Sending only `combined` would force the renderer to invent 4 fake axes — exactly the dual-system Phase 8a is killing.
2. `weakestAxis` is needed by `MintTrameConfiance.empty(missingAxis:)` and by the `oneLineConfidenceSummary()` helper from Phase 4 (Plan 04-01) which speaks the WEAKEST axis only.
3. `enrichmentPrompts` are axis-specific and must travel with the score so the MTC tap-target opens the correct enrichment route. They are also TRUST-02-relevant: every prompt label is an ARB string and goes through the sentence-subject lint.

**`combined: int`** stays in the wire format because the 7 DO-NOT-MIGRATE logic-gate consumers read it. Engine boundary stays clean.

### D-06 — Per-surface `BloomStrategy` decisions (LOCKED defaults)

Defaults from D-01 table. The general rule (and the rule the future custom lint from Phase 11 will enforce) is:

- **Feed contexts** (lists, scrollable cards, items that render together): `onlyIfTopOfList` with the 60ms stagger from MTC-03. This prevents bloom-storm on scroll.
- **Standalone contexts** (heroes, banners, full screens, headers): `firstAppearance`. The MTC blooms once when the surface first becomes visible, then stays at rest.
- **Never `never` in Phase 8a** — `never` is reserved for edge cases like print export and is not used by any of the 11 surfaces.

`confidence_blocks_bar` (#11) is the special case: it does NOT instantiate MTC at all (per AUDIT-01 §extraction sibling). It is renamed/refactored to `DataBlockConfidenceBar` and `BloomStrategy` does not apply.

### D-07 — Coverage gate grep patterns (LOCKED)

`tools/checks/no_legacy_confidence_render.py` runs ripgrep with these patterns inside `apps/mobile/lib/` and fails the build on any hit outside the allowlist:

```
# Local color tier mappings — must come from MTC tokens, not per-file
_confidenceColor\s*\(
confidenceColor\s*\(

# Hard-coded < 70 / < .70 thresholds for confidence labels
confidence(Score)?\s*<\s*70\b
confidence(Score)?\s*<\s*0?\.70\b
confidenceLevel\s*<\s*70\b

# Hand-rolled "indicatif" / approximate flags
isApproximate\s*=
isApproximate\s*\?

# Hard-coded uncertainty band
±\s*15\s*%
\bplusMinus15\b

# Legacy MintConfidenceNotice consumers (replaced by MTC)
MintConfidenceNotice\s*\(

# Legacy ConfidenceBanner / ConfidenceBlocksBar / ConfidenceScoreCard / ConfidenceBreakdownCard direct instantiation
\bConfidenceBanner\s*\(
\bConfidenceScoreCard\s*\(
\bConfidenceBreakdownCard\s*\(

# Hand-rolled per-axis bar painters outside the trust dir
CustomPainter.*[Cc]onfidence
```

**Allowlist** (file-path exemptions, not pattern exemptions):
- `apps/mobile/lib/widgets/trust/**` — MTC owns its tokens and may reference any of these.
- `apps/mobile/lib/services/financial_core/confidence_scorer.dart`
- `apps/mobile/lib/services/confidence/enhanced_confidence_service.dart`
- `apps/mobile/lib/services/biography/freshness_decay_service.dart`
- The 7 DO-NOT-MIGRATE files from AUDIT-01 §DO-NOT-MIGRATE (verbatim).
- `apps/mobile/lib/widgets/coach/confidence_blocks_bar.dart` IF AND ONLY IF it has been renamed to a `DataBlockConfidenceBar` API and the legacy class stays only as a deprecated re-export. The grep tolerates `DataBlockConfidenceBar` but NOT `ConfidenceBlocksBar(`.

Plan 08a-03 owns the script + the wire-up into `.github/workflows/ci.yml` + a drift verification step.

### D-08 — Sentence-subject ARB lint (TRUST-02)

`tools/checks/sentence_subject_arb_lint.py` runs over every ARB key touched (added or modified) by Plans 08a-01 and 08a-02. It enforces:

- Negative or "we don't know yet" statements: subject must be **MINT** (or its first-person plural avatar in the language). Patterns:
  - FR: `MINT n'a pas`, `MINT ne voit pas encore`, `MINT manque de`
  - EN: `MINT can't`, `MINT doesn't yet`
  - DE: `MINT kann noch nicht`, `MINT sieht noch nicht`
  - IT, ES, PT: equivalents.
- Forbidden: `Tu n'as pas`, `Vous n'avez pas`, `You don't`, `Du hast nicht` etc. for the same negative statement (anti-shame: never blame the user).
- Positive / neutral statements are not constrained (the lint only fires on negative-class strings, detected by a small list of trigger lemmas: `pas`, `not`, `nicht`, `non`, `no`).
- Lint operates on the diff: only ARB keys whose value changed in the current branch vs `dev`. Not a full-repo sweep (that would block on legacy strings outside scope).

Plan 08a-03 owns the script. Plan 08a-02 owns the ARB content that has to pass it.

### D-09 — Wave strategy: batched by family, sequential commits

Per-surface migration is too granular (11 commits × test + golden + A14 = unworkable). All-at-once is too risky (one PR with 11 surfaces = unreviewable). The compromise:

- **Batch A — Coach feed family** (5 surfaces): `coach_briefing_card`, `indicatif_banner`, `retirement_hero_zone`, `confidence_blocks_bar` (sibling refactor), and the screen-level `cockpit_detail_screen`. One commit, one golden update batch, one A14 verify.
- **Batch B — Profile family** (3 surfaces): `trajectory_view`, `futur_projection_card`, `narrative_header`. One commit, one golden update batch.
- **Batch C — Home + Retirement family** (3 surfaces): `confidence_score_card`, `confidence_banner`, `retirement_dashboard_screen`. One commit, one golden update, one A14 verify on the home surface (per ROADMAP success criterion 5).

All three batches live under Plan 08a-02. Batches commit in alphabetical order (A, B, C) so the coverage gate (Plan 08a-03) sees a strictly monotonic decrease in legacy hits.

### D-10 — `flutter analyze` 0-error gate after every batch

Every batch ends with `flutter analyze` returning 0 errors AND the test file count not regressing. MTC-12 lcov pre/post delta is captured by Plan 08a-03 and compared at the end of Plan 08a-02.

### D-11 — Anti-shame inheritance

Per `feedback_anti_shame_situated_learning.md`: every MTC empty state and every enrichment prompt copy on the 11 surfaces must speak in MINT-as-subject form, never "tu n'as pas rempli". The TRUST-02 lint enforces this mechanically. Editorially, all 11 surfaces inherit the situated-learning posture: an empty state is an invitation, not a deficit report.

---

## Decision coverage matrix

| REQ | Plan | Notes |
|---|---|---|
| MTC-10 | 08a-02 | All 11 surfaces migrated per D-01 |
| MTC-11 | 08a-02, 08a-03 | DO-NOT-MIGRATE list honored; coverage gate allowlist enforces it |
| MTC-12 | 08a-03 | lcov pre/post baseline + CI gate |
| TRUST-02 | 08a-02, 08a-03 | Sentence-subject ARB lint + content pass |

All 4 requirements covered. No PARTIAL.

---

## Out of scope

- New axis on `EnhancedConfidence` (would need an ADR).
- Migrating the deferred residue list from D-01 (any non-11 site). They land in a Phase 8a follow-up OR earlier in Plan 08a-02 §Stretch if the executor has budget.
- Touching the 7 DO-NOT-MIGRATE consumers.
- Rewriting `confidence_scorer.dart`, `enhanced_confidence_service.dart`, `freshness_decay_service.dart` — engine sources stay untouched.
- The hypotheses footer real-data wiring (Phase 4 shipped the footer plumbing; Phase 8a wires the data per surface only when the surface has a `.detail()` slot — most of the 11 use `.inline()`).
- Phase 11 custom lint that forbids MTC instantiation without an explicit `BloomStrategy` (lands in Phase 11).

## Pitfalls to watch

- **P4 silent coverage loss** — mitigated by MTC-12 lcov pre/post + Plan 08a-03 gate.
- **P5 MTC semantic conflation** — mitigated by D-01 honoring AUDIT-01's `extraction` sibling carve-out for `confidence_blocks_bar` (#11).
- **The "façade sans câblage" trap** (memory: feedback_facade_sans_cablage.md) — every batch's done-criterion includes a runtime smoke check, not just an analyzer pass. The MTC must actually paint on each surface in a real screen pump.
- **Backend/mobile drift on EnhancedConfidence wire shape** — Plan 08a-01 commits backend + mobile in the same PR with an integration test that round-trips JSON.
