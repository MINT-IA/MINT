# Phase 4: L1.2a MTC Component + S4 Migration - SUMMARY

**Completed:** 2026-04-08
**Branch:** `feature/v2.2-p0a-code-unblockers`
**Status:** GREEN — 3/3 plans landed

## Plans

| # | Plan | Commits | Tests | Notes |
|---|---|---|---|---|
| 04-01 | MTC component build | 1 (`b26bdd96`) | 49 new | Widget + BloomStrategy + 4 ARB keys × 6 langs |
| 04-02 | S4 migration | 2 (`8e39dd0c`, `1ccb4e37`) | 18 new (8 DELETE cleanup + 10 MTC wiring) | S4 is introduction (null-fallback), deferred to 8a |
| 04-03 | Golden test infra | 3 (`6b06b9e7`, `e8420de4`, `1dd93e82`) | 7 helper tests + 3 MTC masters | Dual-device (iPhone 14 Pro + Galaxy A14), CI helper-only |

**Total:** 6 execution commits. Baseline grew 9134 → 9211 (+77 net tests).

## Key outcomes

- **MintTrameConfiance** lives at `apps/mobile/lib/widgets/trust/mint_trame_confiance.dart` with `BloomStrategy` enum, derived visually from NYT confidence bands + Apple Weather + Things 3 microtypo + Arc 200-300ms bloom + Stripe "not yet certain" patterns. Zero VZ-style bars. All AAA tokens from Phase 2.
- **S4 introduction** (not migration per D-07): `response_card_widget.dart` gained 6 DELETE cleanups + 3 threaded params + conditional MTC slot. `confidence: null` at all call sites until Phase 8a extends the response model and flips the wiring.
- **Golden infrastructure** shipped as per Phase 1 D-04 expert decision: dual-device (iPhone 14 Pro 390×844 @ 3.0x + Galaxy A14 411×917 @ 2.625x), helper at `test/goldens/helpers/screen_pump.dart`, 3 MTC masters committed, 3 S4 golden placeholders skipped pending model wiring. CI runs helper unit tests only (pixel goldens excluded due to cross-platform font flake — documented in README).

## Visual design references (locked for future phases)

Per the new memory `feedback_vz_content_not_visual.md`:
- NYT data viz (confidence bands)
- Apple Weather (soft range bars)
- Things 3 / Linear / Raycast (microtypo + density)
- Arc browser (bloom 200-300ms)
- Stripe Atlas ("not yet certain" states)
- Aesop / Chloé (sublime minimalism)

**Never reference VZ / Raiffeisen / UBS / PostFinance for visual decisions.** Content rigor only.

## Deviations

1. **S4 is "introduction", not "migration"** — `response_card_widget.dart` had ZERO pre-existing confidence rendering. The term "S4 migration" in ROADMAP is a misnomer. Correctly documented in CONTEXT D-07.
2. **MTC confidence null-fallback** — ResponseCard model lacks the `confidence` field. Phase 4 ships the slot infrastructure; Phase 8a will extend the model and flip callers. Bloom will not fire on device until Phase 8a.
3. **T1 VZ teardown cancelled entirely** — expert decision 2026-04-08, VZ rejected as visual benchmark (dated Swiss-bank UX). Touch budget dropped from 6 to 5.
4. **Golden CI scope = helper-only** — pixel goldens excluded due to macOS↔Linux font flake. Masters committed for local regression; CI runs `test/goldens/helpers/` only.
5. **MTC folder name `widgets/trust/` not `widgets/mtc/`** — executor chose semantic over acronym. Matches existing convention. No change requested.

## Gate results

| Gate | Result |
|---|---|
| `flutter analyze lib/` | 0 errors |
| `flutter test` full suite | 9211 passed / 5 skipped / 3 allowlist baseline failures |
| `flutter test test/widgets/trust/` | 49/49 green |
| `flutter test test/widgets/coach/` | 726/726 green |
| `flutter test test/goldens/helpers/` | 7/7 green |
| CI drift guard (voice cursor contract) | clean |
| `no_chiffre_choc.py` CI gate | clean |

## What Phase 4 unblocks

- **Phase 5** (Voice Cursor Spec full) — independent, already could start
- **Phase 7** (Landing v2) — can consume MTC for landing trust markers
- **Phase 8a** (MTC 11-surface migration) — has the component + AUDIT-01 42-site list, just needs to extend ResponseCard model + flip the 11 consumers
- **Phase 8c** (Polish Pass #1) — has the golden infrastructure ready, goldens will be the primary review surface
- **Phase 9** (MintAlertObject) — MTC is a sibling primitive, shares the trust widget tree

## Branch state

`feature/v2.2-p0a-code-unblockers` at HEAD — 34 commits ahead of dev (25 prior + 1 Phase 3 audit + 1 Phase 4 planning + 6 Phase 4 execution + 1 SUMMARY pending this commit).

## Next

Phase 5: L1.6a Voice Cursor Spec (full) — extends the v0.5 extract into the full authoritative spec + 50 frozen reference phrases + few-shot mitigation. Independent of Phase 4. No user touch expected.
