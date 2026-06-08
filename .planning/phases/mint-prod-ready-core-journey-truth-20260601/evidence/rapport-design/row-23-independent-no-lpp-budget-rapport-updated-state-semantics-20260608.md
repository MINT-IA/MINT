---
description: Row 23/CJT-063 Budget and Rapport updated-state semantics regression proof for the independent/no-LPP restart/profile-update path.
---

# Row 23r - Budget/Rapport Updated-State Semantics

Date: 2026-06-08

## Scope

This proof tightens CJT-063 after Row 23n and Row 23q. It covers the
`independent_no_lpp_income_reality` updated-state facts used by the restart and
profile-update runtime flow:

- professional income: `96'000 CHF/an`
- monthly cashflow proxy: `CHF 8'000`
- planned 3a: `6'000 CHF/an`
- remaining 3a room: `13'200 CHF/an`

It focuses on Budget and Rapport regression coverage. It does not prove
runtime VoiceOver/focus traversal and does not prove live backend/LLM scoring.

## Change

- Added a Budget semantics regression test that hydrates the independent/no-LPP
  profile with updated annual income `96'000` and monthly income `8'000`.
- The Budget test asserts that normal semantics expose the updated
  `CHF 8'000` cashflow in the formula and flow map, reject stale `CHF 7'200`,
  reject salaried wording, and keep the `budget_income_basis` proof anchor out
  of ordinary traversal when proof anchors are disabled.
- Added a Budget proof-anchor regression test that enables opt-in anchors for
  the same updated state and asserts
  `q_self_employed_net_income_annual_chf=96000`,
  `monthly_net=CHF 8'000`, and no stale `86400` / `CHF 7'200` basis.
- Added a Rapport proof-anchor regression test that hydrates the same updated
  facts and asserts `annual=96000`, `max3a=19200`, `planned3a=6000`, and
  `remaining=13200`.
- The Rapport test rejects stale or salaried/LPP values:
  `annual=86400`, `remaining=11280`, `max3a=7258`, and `max3a=7056`.

## Proof Commands

Run from `apps/mobile`.

```bash
flutter test test/screens/budget_screen_smoke_test.dart --plain-name "BudgetScreen independent no-LPP updated-income semantics reject stale cashflow"
flutter test test/screens/budget_screen_smoke_test.dart --plain-name "BudgetScreen E2E proof anchor tracks updated independent no-LPP income"
flutter test test/screens/advisor_banking_smoke_test.dart --plain-name "independent no-LPP report proof anchor tracks updated 3a basis"
flutter test test/screens/budget_screen_smoke_test.dart test/screens/advisor_banking_smoke_test.dart
```

## Result

- Budget updated-state semantics test: `All tests passed`.
- Budget updated-state proof-anchor test: `All tests passed`.
- Rapport updated-state proof-anchor test: `All tests passed`.
- Combined Budget/Rapport smoke suite: `70` tests passed.

## Explicit Limits

- This is widget-level regression coverage, not a new iPhone runtime proof.
- Normal Budget traversal is still tested without exposing
  `budget_income_basis`; the machine anchor remains opt-in through
  `MINT_E2E_PROOF_ANCHORS=true`.
- Runtime VoiceOver/focus traversal still requires the Row 23p physical-device
  manual protocol.
- CJT-063 / Row 23 remains `PARTIAL`.
