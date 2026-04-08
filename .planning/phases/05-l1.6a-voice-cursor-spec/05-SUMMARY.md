# Phase 5: L1.6a Voice Cursor Spec (full) - SUMMARY

**Completed:** 2026-04-08
**Status:** GREEN — 3/3 plans landed

## Plans
| # | Plan | Commits | Outcome |
|---|---|---|---|
| 05-01 | Spec extend §9-§14 + cost delta | 2 | 1321 lines, 50 illustrative phrases, 100% anti-shame pass, 0 banned terms |
| 05-02 | 50 frozen phrases + lint + README | 2 | 10 per N level, 12 mined + 38 fresh, SHA256 frozen `75293279...` |
| 05-03 | 20 anti-examples §13 | 1 | 6 failure families, spec grew to 1630 lines |

**Total:** 5 execution commits. Plan 05-01 also added `docs/COACH_COST_DELTA.md`.

## Key artifacts
- `docs/VOICE_CURSOR_SPEC.md` — 1630 lines, canonical spec for Phases 6/7/9/11
- `tools/voice_corpus/frozen_phrases_v1.json` — 50 phrases, SHA256 frozen, Krippendorff-ready for Phase 11
- `tools/voice_corpus/lint_anti_shame.mjs` — Node lint, enforces 6 anti-shame checkpoints + banned terms
- `tools/voice_corpus/README.md` — sampling rules + v2 addition protocol
- `docs/COACH_COST_DELTA.md` — few-shot vs fine-tune analysis, few-shot wins at current scale

## What Phase 5 unblocks
- **Phase 6** (Voix Régionale): §14 regional stacking rules are the baseline for VS/ZH/TI carve-outs
- **Phase 9** (MintAlertObject): §11 narrator grep spec + §4 narrator wall define what the alert component can import
- **Phase 11** (Krippendorff validation): has the 50 frozen phrases + the lint script + the cost-delta decision

## Deviations
1. **§13 placeholder in 05-01** then filled in 05-03 with fresh context (D-10 adversary mode) — prevented goodness bias from Plans 01+02 polluting adversary writing.
2. **Backend had no FR fallback templates to mine** — distribution shifted to 12 mined / 38 fresh (vs planned ~20/30). Acceptable, lint still green.
3. **6 failure family names from executor differ from orchestrator prompt** (prescription drift / shame induction / tone-lock / sensitivity instead of the 6 I listed). Semantically equivalent coverage.
4. **§11 narrator grep gate spec only, CI wiring deferred to Phase 11** per D-12 — avoids false positives on half-migrated surfaces from Phases 6-9.

## Branch state
`feature/v2.2-p0a-code-unblockers` — 42 commits ahead of dev.

## Next
Phase 6: L1.4 Voix Régionale VS/ZH/TI — 3 canton ARB carve-outs, backend dual-system killed, native validators. No user touch.
