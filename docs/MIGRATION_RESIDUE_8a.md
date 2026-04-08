# MIGRATION RESIDUE — Phase 8a (MTC 11-surface migration)

**Phase**: 08a-l1.2b-mtc-11-surface-migration
**Plan**: 08a-03 (CI lint gates + residue tracking)
**Status**: baseline — will shrink as Plan 08a-02 migrations land
**Owner**: `julien.battaglia@mint`
**Related gate**: `tools/checks/no_legacy_confidence_render.py`

> **This is NOT a Phase 8a scope miss.**
> AUDIT-01 classified 42 confidence-rendering hits. Phase 8a closes the
> 11 highest-leverage `calculation` surfaces (Plan 08a-02, batched A/B/C)
> and locks the 7 DO-NOT-MIGRATE logic-gate consumers. The files listed
> below are lower-priority surfaces, sibling-component candidates, or
> future-phase work. They are documented, gated by CI, and will be closed
> in explicit follow-up plans.

---

## Purpose

The Phase 8a coverage gate (`no_legacy_confidence_render.py`) grep-scans
`apps/mobile/lib/` for 14 legacy patterns (`_confidenceColor(`,
`confidence < 70`, `±15%`, direct `ConfidenceBanner(` instantiation, etc.).
On a fully-migrated tree the only allowed hits would be inside:

1. `apps/mobile/lib/widgets/trust/` — MTC owns its tokens.
2. Engine sources (`confidence_scorer.dart`, `enhanced_confidence_service.dart`, `freshness_decay_service.dart`).
3. The 7 DO-NOT-MIGRATE logic-gate consumers from AUDIT-01 §DO-NOT-MIGRATE.

Everything else must either consume `MintTrameConfiance` OR be listed in
this doc and in the script's `RESIDUE_BASELINE` set. This doc is the
audit trail. Any entry in the residue baseline without a row here is a
broken contract.

---

## Residue table

### A. Plan 08a-02 migration targets — un-migrated at Plan 08a-03 land time

These are the 11 surfaces Plan 08a-02 will migrate to MTC. Plan 08a-02
Batch A was aborted and reverted (see `08a-02-batch-a-FAILURE.md`), so
the baseline at Plan 08a-03 land still counts them as residue. Each
entry is removed from `RESIDUE_BASELINE` as its batch lands on `dev`.

| # | File | AUDIT-01 row | Batch | Target phase | Disposition |
|---|---|---|---|---|---|
| 1 | `apps/mobile/lib/widgets/home/confidence_score_card.dart` | 14 | C | 8a Plan 08a-02 | Migrate to `MintTrameConfiance.inline()` + feed-context bloom |
| 2 | `apps/mobile/lib/widgets/retirement/confidence_banner.dart` | 15 | C | 8a Plan 08a-02 | Collapse to `MintTrameConfiance.detail()` wrapper |
| 3 | `apps/mobile/lib/widgets/coach/retirement_hero_zone.dart` | 2, 3 | A | 8a Plan 08a-02 | Chip + ±15% band move to MTC (planner clarification pending: `uncertaintyBandCopy` parameter) |
| 4 | `apps/mobile/lib/screens/coach/cockpit_detail_screen.dart` | 25 | A | 8a Plan 08a-02 | `.detail()` surface; scorer wiring in-place |
| 5 | `apps/mobile/lib/widgets/coach/plan_preview_card.dart` | 9 | A or B | 8a Plan 08a-02 | `confidenceLevel < 70` collapses to MTC tier read |
| 6 | `apps/mobile/lib/widgets/confidence_breakdown_card.dart` | 16 | B | 8a Plan 08a-02 | Thin frame → deprecated re-export of MTC `.detail()` |

> Surfaces #7-11 from the D-01 table (`coach_briefing_card`,
> `indicatif_banner`, `trajectory_view`, `futur_projection_card`,
> `narrative_header`) currently do NOT trigger the coverage gate grep
> patterns directly (they read `EnhancedConfidence` via typed API, not
> the legacy int/color helpers). They are still in scope for Plan 08a-02
> Batches A/B as renderer swaps, but do not need a residue-baseline row
> here. The gate will catch any regression that re-introduces a legacy
> pattern in them.

### B. Lower-leverage residue — deferred to later phases

These are `calculation`-confidence sites from AUDIT-01 that are NOT in
the ROADMAP-11, NOT in the 7 DO-NOT-MIGRATE list, and that Plan 08a-02
does not cover. Each has a recommended future phase.

| # | File | AUDIT-01 row | Current state | Recommended phase | Rationale |
|---|---|---|---|---|---|
| 7 | `apps/mobile/lib/widgets/precision/smart_default_indicator.dart` | 18 | `_confidenceColor(double c)` local tier mapping | Phase 8b polish | Extraction-confidence sibling, not projection trust. Should migrate to `ExtractionConfidenceChip` sibling (Phase 4 sub-deliverable `EXTRACTION-CHIP`). Not MTC. |
| 8 | `apps/mobile/lib/widgets/premium/mint_confidence_notice.dart` | (wraps #11) | `MintConfidenceNotice(` widget, legacy | Phase 8b polish | Legacy widget replaced by MTC. After all 3 callers (#9, #10, #13) migrate, this file becomes dead code — delete in Phase 8b. |
| 9 | `apps/mobile/lib/screens/onboarding/premier_eclairage_screen.dart` | 31 | Calls `MintConfidenceNotice(` | Phase 10 onboarding v2 | Onboarding v2 rewrites the premier-éclairage moment end-to-end; migrating piecemeal would create churn. Defer. |
| 10 | `apps/mobile/lib/screens/mortgage/affordability_screen.dart` | — (new since AUDIT-01) | Calls `MintConfidenceNotice(` | Phase 8b polish | Mortgage flow polish. Low traffic surface, safe to migrate with other mortgage edits. |
| 11 | `apps/mobile/lib/screens/demenagement_cantonal_screen.dart` | — (new since AUDIT-01) | Calls `MintConfidenceNotice(` | Phase 8b polish | Cantonal move flow. Same reasoning as #10. |
| 12 | `apps/mobile/lib/screens/documents_screen.dart` | 36 (adjacent) | `_confidenceColor(int confidence)` local helper for OCR confidence display | Phase 8b polish | Extraction confidence (OCR), not projection trust. Belongs to `ExtractionConfidenceChip` sibling. Not MTC. |
| 13 | `apps/mobile/lib/screens/arbitrage/arbitrage_bilan_screen.dart` | 32 | `_confidenceColor(double score)` local helper | Phase 9 arbitrage sweep | One of 4 arbitrage screens (#32-35 in AUDIT-01). All migrate together when Phase 9 rewrites the arbitrage family; piecemeal migration would churn 4 screens twice. |
| 14 | `apps/mobile/lib/services/coach/prompt_registry.dart` | — (new since AUDIT-01) | Reads `ctx.confidenceScore < 70` inside a system prompt string literal (engine-adjacent, not a renderer) | Phase 8b polish | This is a COACH PROMPT, not a UI surface. The `< 70` threshold appears inside an interpolated system-prompt string telling Claude to "mentionne les fourchettes, pas les absolus" when confidence is low. It's a logic-gate consumer analogous to DO-NOT-MIGRATE #1-7, but was not listed in AUDIT-01 because it post-dates the audit. Recommended disposition: either add to DO-NOT-MIGRATE list (adjacent to #5, #6) or refactor to read `enhancedConfidence.combined < 70` via the engine boundary. Low urgency — the prompt content is internal, not user-facing. |

### C. Transitively absorbed (no action needed)

The following AUDIT-01 sites were called out in Plan 08a-02 as
potentially in scope but are transitively absorbed by one of the 11
migrations and do not need their own entry:

| File | Absorbed by |
|---|---|
| `apps/mobile/lib/screens/confidence/confidence_dashboard_screen.dart` | Becomes the MTC `.detail()` deep-dive route (Plan 08a-02 Batch A — cockpit entry point) |
| `apps/mobile/lib/widgets/confidence/confidence_breakdown_chart.dart` | Migrates with its sole caller `confidence_breakdown_card.dart` (residue row #6) |
| `apps/mobile/lib/widgets/premium/mint_ligne.dart` | Tier colors come from MTC tokens via the design system; file stops reading raw confidence directly. Verify during Plan 08a-02. |

---

## Counts

- **AUDIT-01 total classified hits**: 42
- **Phase 8a Plan 08a-02 migration targets**: 11 (D-01 table)
- **DO-NOT-MIGRATE (MTC-11 lock)**: 7 (AUDIT-01 §DO-NOT-MIGRATE)
- **Residue documented here**: 14 entries (6 un-migrated targets + 8 deferred)
- **Transitively absorbed**: 3
- **Remaining unexplained**: 0

Sum: 11 + 7 + 8 (deferred) + 3 (absorbed) + engine sources (3) + extraction/freshness siblings (10 — AUDIT-01 rows 4, 18, 20, 22, 28, 29, 36, 37, 38, 39) ≈ 42. The accounting closes.

> **Rows 7-8 in the residue baseline** are intentional Plan 08a-02 back-compat: they both live in (A) migration targets OR (B) deferred, never both. The CI gate's `RESIDUE_BASELINE` set is the single source of truth for which files are currently allowed to carry legacy patterns.

---

## How to shrink this list

When a residue file is migrated (or deleted):

1. Remove its path from `RESIDUE_BASELINE` in `tools/checks/no_legacy_confidence_render.py`.
2. Remove its row from this doc.
3. Run `python3 tools/checks/no_legacy_confidence_render.py` — it must still exit 0.
4. Commit both changes in the same PR that lands the migration.

The gate ratchets monotonically: once a file leaves the baseline, any
future PR that re-introduces a legacy pattern in it fails CI.

## How to grow this list (escape valve)

If a legitimate new file must reference a legacy pattern (e.g. a test
helper, a deprecated re-export, a one-off compatibility shim):

1. Add a row to this doc explaining WHY, with a ticket ID and a
   recommended future phase for cleanup.
2. Add the file path to `RESIDUE_BASELINE` in the lint script with a
   comment pointing at the row here.
3. The CI gate will then treat it as allowlisted until the ticket closes.

**Silent additions are forbidden.** The gate's error message points
reviewers at this doc explicitly.
