# Phase 7: L1.7 Landing v2 (S0 Rebuild) - SUMMARY

**Completed:** 2026-04-08
**Status:** GREEN — 3/3 plans landed

## Plans
| # | Plan | Commits | Outcome |
|---|---|---|---|
| 07-01 | Paragraphe-mère i18n | 1 (`c776df8b`) | 4 keys × 6 locales = 24 ARB entries, FR locked + 5 translations |
| 07-02 | Landing rebuild | 2 (`refactor + ci`) | 861 → 185 LOC (−676), 2 CI lint gates, widget test 4/4 green |
| 07-03 | Dual-device goldens + contrast | 1 (`a231cddf`) | 4 masters (iPhone 14 Pro + Galaxy A14, FR + reduced-motion), 4/4 contrast ≥ 7:1 |

**Total:** 4 execution commits.

## Key outcomes
- **Landing is now a calm promise surface:** single paragraphe-mère, single CTA, zero numbers, zero financial_core imports (CI lint enforced), zero hero chart, zero trust badges.
- **Paragraphe-mère locked:** *"Mint te dit ce que personne n'a intérêt à te dire. Sur tes assurances, ton 3a, ton salaire, ton bail, ton couple, tes impôts. Calmement. Sans te vendre quoi que ce soit."*
- **Hidden login affordance** (long-press wordmark, D-12) — deliberate bet, may be reopened after Phase 10.5 friction pass.
- **Dual-device goldens** verified layout on iPhone 14 Pro AND Galaxy A14 (narrower logical width), paragraph centered, CTA breathing room, legal footer pinned to safe area, no clipping.
- **4 AAA contrast assertions** pass ≥ 7:1 for paragraph body + CTA + secondary + muted text against craie.

## Deviations
- German legal footer uses **FIDLEG** (correct Swiss name), Italian uses **LSerFi** — per planner note, do NOT normalize to LSFin.
- Motion handling: reduced-motion variant converges byte-identical to animated-final state (D-08), verified in both golden masters.
- MTC deliberately NOT on landing (D-05) — no data to render confidence against, and a trust marker would compete with the paragraph for weight.

## Baseline deltas
- Landing LOC: 861 → 185 (−78% code reduction)
- New tests: 4 widget tests + 4 golden masters + 4 contrast assertions
- CI gates: +2 (landing_no_numbers, landing_no_financial_core)

## Branch state
`feature/v2.2-p0a-code-unblockers` — 59 commits ahead of dev.

## What Phase 7 unblocks
- **Phase 10** (Onboarding v2): the landing → intent → chat golden path can now be built end-to-end
- **Phase 10.5** (Friction pass): landing is the entry point for the Galaxy A14 walkthrough
- **Phase 12** (Ship gate): AAA gate passes on landing surface already verified

## Next
Phase 8a: L1.2b MTC 11-Surface Migration — the big migration using the AUDIT-01 42-site list + MTC component from Phase 4. No user touch expected.
