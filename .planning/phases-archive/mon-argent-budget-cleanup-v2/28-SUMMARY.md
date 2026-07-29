# Phase 28 — Coach 3a tax-impact wording gate

Date: 2026-05-27

## Goal

Close the user-reported trust issue where the coach could appear to present the
3a annual ceiling as a tax saving, e.g. "7258 CHF d'économie d'impôt en jeu".

## Change

- Changed the 3a deadline alert copy from `Impact fiscal estimé` to
  `Impact fiscal indicatif`.
- Kept the amount-to-pay and tax-impact amounts structurally separate:
  - `verser CHF X en 3a` = deductible contribution still available.
  - `Impact fiscal indicatif: ~CHF Y` = estimated tax impact.
- Hardened the number-gate regression test so future copy cannot:
  - put the estimated saving in the "verser" slot;
  - label the deductible contribution as an "économie";
  - use promise-style wording such as `gain fiscal`, `tu économises`,
    `tu gagnes`, or `rendement fiscal`.

## Files

- `apps/mobile/lib/services/coach_narrative_service.dart`
- `apps/mobile/test/services/coach_narrative_number_gate_test.dart`

## Verification

- Red-first check: updated test failed on the old `Impact fiscal estimé` copy.
- `flutter test test/services/coach_narrative_number_gate_test.dart` — PASS.
- `flutter analyze lib/services/coach_narrative_service.dart test/services/coach_narrative_number_gate_test.dart` — PASS.
- `git diff --check` — PASS.
- MCP French copy checks:
  - `check_banned_terms` — clean.
  - `check_accent_patterns` — clean.
- Claude Opus 4.7 review:
  - Verdict: APPROVE.
  - Blocking findings: none.
  - Applied non-blocking improvements for formatted amount disjointness and
    expanded promise-word deny-list.

## Self-evaluation

Accuracy/effectiveness: 9/10.

Why not 10: the test is still anchored on one VD fixture. A future hardening
phase should parameterize this invariant across multiple cantons and income
bands.

How to make it 10: add a table test for VD/GE/ZG and low/mid/high income
profiles, then run the same positional and promise-copy invariants across the
matrix.
