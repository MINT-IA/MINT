---
description: Row 23 local proof that Budget surfaces independent/no-LPP 3a capacity checks before a user increases 3a.
status: verified-local
date: 2026-06-08
linked_bug: CJT-063
---

# Row 23u - Budget Independent/No-LPP Capacity Guard

## Scope

This is a focused Row 23 / `CJT-063` local guidance-depth proof for the
`independent_no_lpp_income_reality` persona. It proves that `/budget` now
surfaces the same independent/no-LPP capacity guard already expected in
`/rapport`: legal 3a room is not enough to decide a payment, so the user must
also check AVS-independent status, taxable income, risk cover, liquidity, and
income volatility.

It does not prove real VoiceOver speech, physical-device focus traversal, live
backend/LLM scoring, or a new iPhone runtime flow. Row 23 remains `PARTIAL`.

## Problem

After Row 23t, Budget action semantics were clean, but Budget still did not
expose the practical pre-payment checks a self-employed user needs before
increasing a 3a payment without LPP. That is a real user gap: the legal no-LPP
3a ceiling and monthly Budget capacity are different decisions.

## Change

`BudgetScreen` now detects `employmentStatus == 'independant'` with no LPP
balance and renders `budget_independent_no_lpp_capacity_guard` after the
next-action card. The card reuses the already localized
`reportAction*3aIndependentNoLpp` strings, so guidance stays consistent with
Rapport and avoids new ARB churn. It names AVS-independent status, declared
activity income, taxable income, monthly budget capacity under income
volatility, risk cover, optional LPP, 3a, and liquidity. The semantics node uses
one explicit label and excludes child duplication.

## Verification

Red proof:

```bash
cd apps/mobile
flutter test test/screens/budget_screen_smoke_test.dart --plain-name "BudgetScreen independent no-LPP exposes 3a capacity guard"
```

Expected failure before the fix: `Bad state: Finder returned no matching
elements` for `budget_independent_no_lpp_capacity_guard`.

Green proof:

```bash
cd apps/mobile
flutter test test/screens/budget_screen_smoke_test.dart --plain-name "BudgetScreen independent no-LPP exposes 3a capacity guard"
flutter analyze lib/screens/budget/budget_screen.dart test/screens/budget_screen_smoke_test.dart
flutter test test/screens/budget_screen_smoke_test.dart test/screens/advisor_banking_smoke_test.dart
flutter test test/services/e2e_runtime_flags_test.dart test/screens/budget_screen_smoke_test.dart test/screens/advisor_banking_smoke_test.dart
```

Results:

- focused Budget capacity-guard test: pass;
- targeted analyze: no issues;
- Budget/Rapport smoke suite: `71/71` pass;
- E2E flags + Budget/Rapport smoke suite: `73/73` pass.

## Guardrails

The Budget widget test asserts the useful guidance fragments (`statut AVS
indépendant`, `revenu imposable`, `volatilité de tes revenus`, `couvertures
risque`, `LPP facultative`, `liquidité`) and rejects known bad/product-like or
salaried-only surfaces: `Plafond 3a salarié`, `7’258`, account-opening wording,
provider names, and `60% actions`.

## Remaining CJT-063 Work

Still required before closing `CJT-063`: physical-device VoiceOver/focus
traversal for Coach/Budget/Rapport, live backend/LLM scoring, runtime iPhone
visibility of the new guard, and production/staging path proof for the same
updated profile facts.
