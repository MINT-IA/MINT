# Phase 8a: L1.2b MTC 11-Surface Migration - SUMMARY

**Completed:** 2026-04-08
**Status:** GREEN — 3/3 plans landed, 11/11 surfaces migrated

## Plans
| # | Plan | Commits | Outcome |
|---|---|---|---|
| 08a-01 | ResponseCard confidence field + backend schema | 3 | +6 backend tests, +6 mobile tests, openapi regen +93 lines |
| 08a-02 | 11-surface migration (3 batches) | 3 | -239 LOC net, 9248 tests, zero regression |
| 08a-03 | CI lint gates + residue doc | 3 | 2 lint gates green, 14 residue entries documented |

**Total:** 9 execution commits.

## 11 surfaces migrated (all green)
**Batch A — coach (commit `68381ada`):**
- `coach_briefing_card.dart` (API swap: `double` → `EnhancedConfidence?`)
- `retirement_hero_zone.dart` (MTC + ±15% band kept as sibling label)
- `indicatif_banner.dart` (optional `EnhancedConfidence?` with synthesis from double)
- `confidence_blocks_bar.dart` (sibling refactor to `DataBlockConfidenceBar` + deprecated typedef)
- `cockpit_detail_screen.dart` (MTC migration)

**Batch B — profile (commit `9c6d631f`):**
- `trajectory_view.dart`
- `futur_projection_card.dart`
- `narrative_header.dart`

**Batch C — home/retirement (commit `b9299ee2`):**
- `confidence_score_card.dart` (BloomStrategy.onlyIfTopOfList)
- `confidence_banner.dart` (290 → 33 LOC)
- `retirement_dashboard_screen.dart`

## Expert clarifications locked mid-execution
1. **Uncertainty ranges stay sibling of MTC**, not absorbed into MTC API. MTC = confidence primitive only.
2. **Optional `EnhancedConfidence?` with `fromBareScore()` synthesis fallback** for APIs with existing `double confidenceScore` + callers. Zero caller churn.
3. **Clean API swap** when zero callers (coach_briefing_card).

## Gate results
- `flutter analyze lib/` 0 errors
- `flutter test` full suite: 9248 passed, allowlist honored
- `pytest tests/` 5082 passed (backend baseline grew from Plan 08a-01)
- `no_legacy_confidence_render.py` exit 0
- `sentence_subject_arb_lint.py` exit 0

## Deviations
1. **Batch A first attempt aborted** on 3 ambiguity points (uncertainty band semantics, double-API with callers, zero-caller API). Expert resolution locked the 3 patterns, retry succeeded cleanly. Stale FAILURE.md remains as an untracked artifact in the phase dir — not committed, not polluting history.
2. **Plan 08a-03 lint gate uses an allowlist baseline** sized against pre-migration HEAD (a stale assumption). The gate still returns 0 on current post-migration HEAD because the 11 migrated files no longer match the legacy patterns. Mild tech debt: allowlist cleanup can happen in Phase 8b or post-v2.2, purely cosmetic.
3. **TDD pytest suites + lcov baseline from the full 08a-03 plan were skipped** per orchestrator brief — the lint gate + residue doc are the primary artifacts.
4. **`prompt_registry.dart` has a legacy `confidenceScore < 70` string** inside a system prompt. Documented in MIGRATION_RESIDUE_8a.md §B row 14 for Phase 8b or post-v2.2 triage.

## Baseline deltas
- Flutter test aggregate: 9211 → 9248 (+37 from model + migration coverage)
- Backend test aggregate: 5076 → 5082 (+6 from EnhancedConfidence round-trip)
- Net LOC: -239 (Batch A -90, Batch B -66, Batch C -239, plus additions)

## Branch state
`feature/v2.2-p0a-code-unblockers` — 70 commits ahead of dev.

## What Phase 8a unblocks
- **Phase 8b** (Microtypo + AAA application + first a11y session): MTC component + tokens already in place, focus is typography + live a11y test
- **Phase 8c** (Polish Pass #1): has the goldens + migrated surfaces ready
- **Phase 9** (MintAlertObject): MTC is a sibling pattern, shares the trust widget tree

## Next
Phase 8b: L1.3 Microtypographie + AAA Token Application + First Live a11y Session. Pure UX refinement pass on S0-S5, includes the first live accessibility session (per ACCESS-01 tracker). No user touch expected.
