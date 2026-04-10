# Phase 6: L1.4 Voix Régionale VS/ZH/TI - SUMMARY

**Completed:** 2026-04-08
**Status:** GREEN — 4/4 plans landed

## Plans
| # | Plan | Commits | Outcome |
|---|---|---|---|
| 06-01 | Dual-system audit | 1 | 4 backend symbols + 2 call sites + ~250 LOC mobile mapped as kill targets; 7 side findings including VD→VS routing flip |
| 06-04 | Validator coordination doc | 1 | 217-line protocol, recruitment template, review rubric, tracking table |
| 06-03 | ARBs + delegate + wiring | 5 | 75 strings × 3 cantons (VS/ZH/TI), custom delegate, 26 new tests, all marked @@x-unvalidated |
| 06-02 | Backend kill + codegen + drift guard | 4 | Dual-system deleted, VD→VS flip landed, codegen+drift, 32 new backend tests |

**Total:** 11 execution commits.

## Key outcomes
- **Backend dual-system killed.** `REGIONAL_MAP`, `_CANTON_TO_PRIMARY`, `_resolve_canton`, `_REGIONAL_IDENTITY` all deleted from `claude_coach_service.py`. Single injection point via `RegionalMicrocopy.identity_block(canton)`.
- **VS is now the Suisse Romande anchor** (was VD). `test_vd_resolves_to_vs_anchor` + secondary canton routing (NE/GE/JU/FR → VS) verified.
- **Codegen bootstrap pattern** — hand-written `regional_microcopy.py` then codegen reproduces it byte-identical for drift guard. Prevents future divergence between mobile ARBs and backend identity blocks.
- **Mobile regional delegate** lives at `apps/mobile/lib/l10n_regional/` (separate dir from `lib/l10n/` to avoid Flutter auto-locale-scan breaking on invalid region codes). 3 regional ARBs × 25 keys each.
- **CI drift guard** wired: `tools/checks/regional_microcopy_drift.py` + grep guard for legacy constants.
- **All 75 regional strings marked @@x-unvalidated** — awaiting native review per `docs/REGIONAL_VOICE_VALIDATORS.md`, D-08 hard gate before production.

## Baseline deltas
- Flutter tests: +26 (regional_localizations_test.dart)
- Backend tests: +33 (regional_microcopy + updated firstjob regional suite)
- Backend baseline: 5043 → 5076

## Deviations
1. **Regional ARB dir name** `lib/l10n_regional/` instead of `lib/l10n/` — executor hit Flutter's auto-locale-scanner on invalid `fr_VS` region code and fell back to the planner's hand-written-delegate path.
2. **VOICE_CURSOR_SPEC §14 stacking note appended** by Plan 06-03 (5 lines) — the §14 already existed from Phase 5, executor added the specific regional stacking order.
3. **Full flutter test suite not re-run at end of Plan 06-03** — targeted gates only per time budget. Backend suite was fully re-run.

## Open items (not blocking Phase 7)
- **Native validator sign-off** for 75 regional strings — async, tracked in `docs/REGIONAL_VOICE_VALIDATORS.md`, coordinates with Phase 11 tester pool. Must land before production ship.
- **Side finding from 06-01:** `pt.arb` file presence is NOT a concern (exists on disk, planner's earlier assumption was stale).

## Branch state
`feature/v2.2-p0a-code-unblockers` — 54 commits ahead of dev.

## What Phase 6 unblocks
- **Phase 7** (Landing v2) — regional voice layer is available; landing can opt in to regional copy via Profile.canton
- **Phase 11** (Krippendorff) — tester pool sharing protocol is documented; phase 6 regional microcopy review is one of the tasks in the shared pool
- **Phase 12** (Ton UX) — the "Ton" chooser can now coexist with regional coloring (stacking order: base N → regional → sensitive cap)

## Next
Phase 7: L1.7 Landing v2 (S0 Rebuild) — calm promise surface, zero numbers, zero inputs, Variante A paragraphe-mère, AAA from day 1. No user touch expected.
