# Phase 31 — LAMal franchise education trust framing

Date: 2026-05-27

## Goal

Remove deterministic saving language from the LAMal education block. A higher
franchise can reduce premiums, but the trade-off is a materially higher
out-of-pocket risk.

## Change

- Replaced `peut te faire économiser` with `peut réduire tes primes`.
- Replaced `économie de prime` with `prime souvent plus basse`.
- Replaced `tu economises environ 1'500 CHF/an` with `la prime peut baisser`
  and explicit `selon la caisse et le canton`.
- Kept and tested the downside: a hospitalization can cost `2'200 CHF` more.
- Softened the alternative model copy from deterministic `offrent 10-20%` to
  conditional `peuvent offrir environ 10 à 20%`.
- Fixed local French accent drift in the touched paragraph.

## Files

- `apps/mobile/lib/data/education_content.dart`
- `apps/mobile/test/data/education_content_test.dart`

## Verification

- Red-first check: the new LAMal education test failed on the old copy.
- `flutter test test/data/education_content_test.dart` — PASS.
- `flutter analyze lib/data/education_content.dart test/data/education_content_test.dart` — PASS.
- `git diff --check` — PASS.
- MCP copy checks:
  - `check_banned_terms` — clean.
  - `check_accent_patterns` — clean.
- Claude Opus 4.7 review:
  - Verdict: PASS_WITH_NOTES.
  - Blocking findings: none.
  - Applied non-blocking notes for accents, model-copy conditionality, and
    stronger test invariants.

## Self-evaluation

Accuracy/effectiveness: 9/10.

Why not 10: the 1'500 CHF/year estimate remains educational copy. A stronger
version would source it from an OFSP-backed model by canton, age group, and
franchise.

How to make it 10: connect the education block to a LAMal premium delta model
and render the figure as a canton-specific estimate when the user profile has a
known canton.
