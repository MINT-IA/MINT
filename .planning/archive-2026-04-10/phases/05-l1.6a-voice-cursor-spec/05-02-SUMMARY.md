---
phase: 05-l1.6a-voice-cursor-spec
plan: 02
status: complete
completed: 2026-04-07
requirements: [VOICE-02]
---

# Phase 5 Plan 02 — Summary

## What shipped
- `tools/voice_corpus/frozen_phrases_v1.json` — 50 frozen phrases, 10 per level (N1..N5), distributed per D-08.
- `tools/voice_corpus/lint_anti_shame.mjs` — pure-Node mechanical gate (schema + banned terms + anti-shame + NBSP + v0.5 §3/§5 caps).
- `tools/voice_corpus/README.md` — 9 sections (purpose, freeze rule, D-08/D-09/D-10, schema, Krippendorff sampling, lint usage, SHA-256 freeze proof).
- `docs/VOICE_CURSOR_SPEC.md` §14.3 — 6 few-shot placeholder comments updated with concrete phrase IDs and first-six-word previews.

## Mined vs fresh (actual split)
- **Mined: 12** — all from `apps/mobile/lib/l10n/app_fr.arb` (`documentsEmptyVoice`, `confidenceLow`, `leasingFondsPropres`, `narrativeAmortizationBody`, `narrativeMarriageBody`, `narrativeSaronBody`, `lppVolontaireGapLabel`, `stepJitRetirementCons`, `optimDecaissementChiffreExplication`).
- **Fresh: 38** — tagged `fresh:phase-5-plan-02`.
- Deviation from D-09 target (~20 mined / ~30 fresh): the backend coach service `services/backend/app/services/coach/claude_coach_service.py` does not carry French fallback templates (only regional prompt fragments), so the ~5 expected mined backend candidates were unavailable. Mining was ARB-only. The 12/38 split is documented in README §4.

## Sensitive-topic × level substitutions (v0.5 §5 cap)
`jobLoss` maps to `sensitiveTopic: "perteEmploi"` which caps at N3. The `jobLoss` slot at N4 and N5 was therefore replaced per D-08:
- **N4**: `N4-006` (tax) and `N4-010` (debt) serve as the `jobLoss` substitution slots. Rationale logged in-phrase.
- **N5**: `N5-006` (tax) and `N5-010` (tax, second slot) serve as the `jobLoss` substitution slots. Rationale logged in-phrase.

No other sensitive-topic × level collisions occurred. All N4/N5 entries carry `sensitiveTopic: null` and `relation: "established"` (lint-enforced).

## Few-shot IDs selected for §14.3
| Slot | ID | lifeEvent |
|------|----|-----------|
| N4 #1 | N4-003 | housing (EPL taxation) |
| N4 #2 | N4-007 | birth (LPP survivor benefit) |
| N4 #3 | N4-009 | debt (Safe Mode) |
| N5 #1 | N5-002 | retirement (44-year AVS gap) |
| N5 #2 | N5-005 | marriage (150 % cap) |
| N5 #3 | N5-008 | inheritance (intestate × concubinage) |

Diversity: 6 lifeEvents across 6 slots. All carry `sensitiveTopic: null` and `relation: "established"` per D-05.

## Rejected mined candidates
None formally rejected — the authoring pass picked 12 clean mined anchors on the first read and did not attempt to salvage checkpoint-failing candidates (per D-09 "do not fix mined phrases — a fixed mined phrase becomes fresh").

## Freeze checksum
```
frozen_phrases_v1.json sha256 = 75293279916f5cd860db99289c7d78d89bb1dd65c9970b404d4684a49e0eea3a
```
Pasted into `tools/voice_corpus/README.md` §9. Phase 11 must verify this hash before starting the α study.

## Lint result
```
OK: 50/50 phrases pass anti-shame checkpoints
     distribution: N1=10, N2=10, N3=10, N4=10, N5=10
```

## Scope hygiene
- No production code touched (no `apps/mobile/lib/` or `services/backend/app/` modifications beyond the single §14.3 placeholder replacement in `docs/VOICE_CURSOR_SPEC.md`).
- Plan 05-01 (spec) and Plan 05-03 (anti-examples) untouched.
- No `package.json` root file existed in the repo; none created (documented here in lieu of a package.json script entry).

## VOICE-02 status: closed
