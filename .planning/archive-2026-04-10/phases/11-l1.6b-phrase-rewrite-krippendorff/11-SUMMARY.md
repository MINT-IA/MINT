# Phase 11: L1.6b Phrase Rewrite + Krippendorff Validation - SUMMARY

**Completed:** 2026-04-08 (partial close, Plan 02 deferred)
**Status:** GREEN on code side (4/5 plans), Plan 11-02 (tester recruitment + α validation) deferred to Phase 12 ship gate

## Plans
| # | Plan | Commits | Status |
|---|---|---|---|
| 11-01 | 30 phrase rewrite + VOICE_PASS_LAYER1 | 3 | ✓ 30/30 anti-shame pass, 1 P0 banned-term fix, 180 @meta annotations |
| 11-03 | N5 hard gate + fragility detector + Profile field | 4 | ✓ deterministic downgrade verified, +42 tests |
| 11-04 | ComplianceGuard adversarial + reverse runner | 4 | ✓ 50/50 adversarial, 24 new patterns, reverse runner shipped |
| 11-05 | @meta level lint + Krippendorff α runner | 4 | ✓ 133 grandfathered keys, runner test α=0.97 fixture |
| 11-02 | Tester recruitment + α validation | 0 | ⏸ DEFERRED — wall-clock 2-3 weeks human dependency |

**Total:** 15 execution commits.

## Key outcomes
- **30 most-used coach phrases rewritten** to VOICE_CURSOR_SPEC, all pass 6 anti-shame checkpoints, 180 `@meta level:` annotations added across 6 locales
- **N5 hard gate** in `claude_coach_service.py`: deterministic template downgrade N5→N4 when `n5IssuedThisWeek ≥ 1`, no re-LLM, 7-day rolling reset
- **Fragility detector** at `services/coach/fragility_detector_service.py`: ≥3 G2/G3 events in 14 days → 30-day fragile mode (N3 cap), single-fire trigger, log purges at 30d
- **Profile.recentGravityEvents** added (Pydantic + SQLA stub + Dart mirror), Alembic stub not run per phase precedent
- **50 adversarial N4/N5 phrases** + 24 new ComplianceGuard HIGH_REGISTER_DRIFT_PATTERNS catching imperative-without-hedge / shame vector / prescription drift / banned terms / absolute claims, 50/50 pass rate
- **Reverse-Krippendorff runner** at `tools/krippendorff/reverse_generation_test.py` with 10 trigger contexts ready for the tester pool
- **`@meta level:` ARB lint** extending sentence_subject_arb_lint, 133 pre-existing keys grandfathered, new keys must annotate
- **Krippendorff α runner** at `tools/voice_corpus/krippendorff_runner.py` with bootstrap CI N=1000, α≥0.67 + CI lower≥0.60 gates, smart per-level slicing on the {N4,N5} high-tone band to avoid zero-variance NaN

## Plan 11-02 deferral rationale
Plan 11-02 requires:
- 15 testers recruited (3 from Phase 6 NDA pool + 12 via Respondent.io paid panel, ~CHF 450)
- Each tester: 30-45 min blind classification of 50 phrases
- Real wall-clock: 2-3 weeks minimum (recruitment lead time + tester scheduling + rating + bootstrap analysis)

**Decision:** Phase 12 success criterion 5 already accepts that the live tester work spans Phases 8b + 11 + 12. Collapsing 11-02 into Phase 12's window is doctrine-compatible. The infrastructure (runner + fixture + UI format + tester instructions) is ALL ready in Plan 11-05; only the actual tester output JSON is missing.

**Action items carried to Phase 12:**
1. Send Respondent.io recruitment posting (Julien)
2. When tester output lands → run `python3 tools/voice_corpus/krippendorff_runner.py path/to/output.json`
3. If α ≥ 0.67 + CI lower ≥ 0.60 → ship gate passes
4. If α < 0.67 → contingency loop (rewrite specific phrases that confused testers, re-run reverse Krippendorff, re-test)

## Deviations
1. **Plan 11-01 consolidated 4 commits → 3** (atomic rewrites + ARB landed together because gen-l10n requires both)
2. **claude_coach_service.py NOT touched by Plan 11-01** — the top-30 phrases live in ARB, not in coach service. Documented deviation, no scope leak.
3. **Plan 11-05 per-level α slicing** uses {N4, N5} high-tone band combined slice (not pure N4/N5) to avoid zero-variance NaN on single-label slices. Documented in runner docstring.
4. **`coachFragilityDisclosure` ARB key not added by Plan 11-03** (strict ownership forbade ARB edits). Future plan must add the localized copy when wiring the biography emission.
5. **Plan 11-02 deferred** as documented above.

## Gate results
- `flutter analyze lib/` 0 errors
- Backend `pytest tests/services/coach/ tests/services/compliance/ tests/schemas/` all green
- 50/50 adversarial pass rate
- N5 deterministic downgrade verified on 5-attempt crisis cluster
- Fragility detector verified on 14-day rolling window + 30-day expiry
- ARB sentence-subject + @meta level lint exit 0
- Krippendorff runner test α≈0.97 on synthetic fixture, all gates pass

## Branch state
`feature/v2.2-p0a-code-unblockers` — 137 commits ahead of dev.

## What Phase 11 unblocks
- **Phase 12 ship gate**: only the live α validation (Plan 11-02 wall-clock) and ACCESS-01/8b live a11y session remain as human-async items
- **Post-milestone**: any phrase that fails Krippendorff can be hot-fixed via the same Plan 11-01 pattern

## Next
Phase 10.5: Friction Pass — Galaxy A14 walkthrough, **first real device user touch (T4)**. Prep already done by Plan 10.5-01.
