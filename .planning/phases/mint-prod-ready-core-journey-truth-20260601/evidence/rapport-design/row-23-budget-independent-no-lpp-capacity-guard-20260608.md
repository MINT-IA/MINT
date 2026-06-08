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

## Runtime Visibility Proof

Follow-up Row 23v proves the same guard is visible in the canonical simulator
route flow. The app was rebuilt and installed on the booted iPhone 16e
simulator with:

```bash
cd apps/mobile
flutter build ios --simulator --debug \
  --dart-define=MINT_E2E_ARCHETYPE=independent_no_lpp_income_reality \
  --dart-define=MINT_DISABLE_BETA_MODAL=true
xcrun simctl install booted build/ios/iphonesimulator/Runner.app
```

Runtime command:

```bash
MINT_WALKER_ARTIFACTS=.planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/maestro-ci/row-23-budget-capacity-guard-runtime-20260608T144941 \
MAESTRO_HARD_LIMIT=420 \
MAESTRO_STALL_THRESHOLD=90 \
bash tools/simulator/maestro_with_watchdog.sh test \
  --debug-output .planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/maestro-ci/row-23-budget-capacity-guard-runtime-20260608T144941/debug \
  --format junit \
  --output .planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/maestro-ci/row-23-budget-capacity-guard-runtime-20260608T144941/result.xml \
  tools/simulator/flows/maestro-perfect-set/flow_row23_independent_no_lpp_runtime.yaml
```

Result: `flow_row23_independent_no_lpp_runtime` passed on
`iPhone 16e - iOS 26.2` with JUnit `tests=1`, `failures=0`, watchdog exit `0`.
Artifacts:

- `evidence/maestro-ci/row-23-budget-capacity-guard-runtime-20260608T144941/result.xml`
- `evidence/maestro-ci/row-23-budget-capacity-guard-runtime-20260608T144941/maestro.log`
- `evidence/maestro-ci/row-23-budget-capacity-guard-runtime-20260608T144941/watchdog-summary.txt`
- `evidence/maestro-ci/row-23-budget-capacity-guard-runtime-20260608T144941/row23-independent-no-lpp-budget.png`
- `evidence/maestro-ci/row-23-budget-capacity-guard-runtime-20260608T144941/row23-independent-no-lpp-rapport.png`

The flow copies `budget_independent_no_lpp_capacity_guard` and runs
`row23_assert_budget_capacity_guard.js`; the script requires the no-LPP
capacity fragments and rejects salary-only/product/provider/allocation
fragments.

## Guardrails

The Budget widget test asserts the useful guidance fragments (`statut AVS
indépendant`, `revenu imposable`, `volatilité de tes revenus`, `couvertures
risque`, `LPP facultative`, `liquidité`) and rejects known bad/product-like or
salaried-only surfaces: `Plafond 3a salarié`, `7’258`, account-opening wording,
provider names, and `60% actions`.

## Remaining CJT-063 Work

Still required before closing `CJT-063`: physical-device VoiceOver/focus
traversal for Coach/Budget/Rapport, live backend/LLM scoring,
production/staging path proof for the same updated profile facts, and broader
Budget/Rapport guidance depth beyond this simulator-proven guard.

## Row 23w Quantified Capacity Addendum

Follow-up Row 23w tightens the same Budget guard so the user sees the
difference between legal room and current monthly capacity. `BudgetScreen`
now computes the remaining legal 3a room through
`Pillar3aRoomCalculator.remainingAnnualRoom(...)` for the
`independent_no_lpp` archetype, then displays the annual value, monthly
equivalent, and current Budget free cashflow in the guard.

For the seeded `independent_no_lpp_income_reality` profile, the local proof
asserts:

- remaining legal 3a room: `CHF 11'280/an`;
- monthly equivalent: `CHF 940/mois`;
- current Budget free cashflow: `CHF 2'578/mois`;
- explicit boundary: `Marge légale ≠ capacité mensuelle`.

Verification:

```bash
cd apps/mobile
flutter test test/screens/budget_screen_smoke_test.dart --plain-name "BudgetScreen independent no-LPP exposes 3a capacity guard"
flutter analyze lib/screens/budget/budget_screen.dart test/screens/budget_screen_smoke_test.dart
flutter test test/screens/budget_screen_smoke_test.dart test/screens/advisor_banking_smoke_test.dart
flutter test test/services/e2e_runtime_flags_test.dart test/screens/budget_screen_smoke_test.dart test/screens/advisor_banking_smoke_test.dart
flutter gen-l10n
```

Results: focused Budget test passed, targeted analyze passed, Budget/Rapport
smoke passed, E2E flags + Budget/Rapport passed (`73/73`), and ARB parity
passed across FR/EN/DE/ES/IT/PT.

Scope limit: this is local widget and localization proof. It does not add
physical-device VoiceOver/focus traversal, live backend/LLM scoring,
production/staging proof, or new simulator runtime proof beyond Row 23v.

## Row 23x Monthly Capacity Shortfall Addendum

Follow-up Row 23x closes a narrower Budget guidance gap that Row 23w still
left to mental arithmetic: when the legal 3a monthly equivalent is higher than
the current free monthly budget, the guard now says so explicitly instead of
only listing the two values side by side.

`BudgetScreen` still computes the legal room through
`Pillar3aRoomCalculator.remainingAnnualRoom(...)`. The new branch derives the
monthly equivalent from the raw annual room, rounds the monthly equivalent and
free budget through the same display path used in the visible summary, then
adds the warning only when the displayed monthly equivalent is positive and
exceeds the displayed free budget:

`Budget libre insuffisant pour couvrir cet équivalent mensuel : vérifie la
trésorerie avant tout versement.`

Local proof covers both sides:

- the existing Row 23w seed keeps `CHF 11'280/an`, `CHF 940/mois`, and
  `CHF 2'578/mois` without the shortfall warning;
- a compressed monthly budget (`CHF -122/mois` free) exposes the shortfall
  warning in the `budget_independent_no_lpp_capacity_guard` semantics label;
- an edge case where the raw monthly equivalent is slightly above `CHF 940`
  but both displayed values are `CHF 940/mois` does not expose the shortfall
  warning;
- the warning rejects product/provider surfaces such as `ouvrir un compte` and
  `UBS`.

Verification:

```bash
cd apps/mobile
flutter test test/screens/budget_screen_smoke_test.dart --plain-name "BudgetScreen independent no-LPP warns when monthly 3a room exceeds free budget"
flutter test test/screens/budget_screen_smoke_test.dart --plain-name "BudgetScreen independent no-LPP shortfall warning follows displayed monthly values"
flutter analyze lib/screens/budget/budget_screen.dart test/screens/budget_screen_smoke_test.dart
flutter test test/screens/budget_screen_smoke_test.dart test/screens/advisor_banking_smoke_test.dart
flutter test test/services/e2e_runtime_flags_test.dart test/screens/budget_screen_smoke_test.dart test/screens/advisor_banking_smoke_test.dart
flutter gen-l10n
```

Results: focused shortfall test passed, displayed-value rounding guard passed,
focused Row 23w positive guard test passed, targeted analyze passed,
Budget/Rapport smoke passed (`73/73`), E2E flags + Budget/Rapport passed
(`75/75`), ARB parity passed across FR/EN/DE/ES/IT/PT, and MCP LSFin/accent
checks passed on the new French copy.

## Row 23x Simulator Runtime Addendum

Follow-up runtime proof now covers the Row 23x shortfall branch on the local
iPhone simulator. The flow builds with
`MINT_E2E_ARCHETYPE=independent_no_lpp_income_reality`, opens the debug-only
direct-input Budget route with `net=4500`, `housing=3900`, and `lamal=600`,
then renders the real `BudgetScreen` while preserving the independent/no-LPP
profile context.

Runtime proof:

```bash
cd apps/mobile
flutter build ios --simulator --debug \
  --dart-define=MINT_E2E_ARCHETYPE=independent_no_lpp_income_reality \
  --dart-define=MINT_DISABLE_BETA_MODAL=true
xcrun simctl install booted build/ios/iphonesimulator/Runner.app

cd ../..
MINT_WALKER_ARTIFACTS=.planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/maestro-ci/row-23-budget-shortfall-runtime-20260608T182944 \
MAESTRO_HARD_LIMIT=420 \
MAESTRO_STALL_THRESHOLD=90 \
bash tools/simulator/maestro_with_watchdog.sh test \
  --debug-output .planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/maestro-ci/row-23-budget-shortfall-runtime-20260608T182944/debug \
  --format junit \
  --output .planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/maestro-ci/row-23-budget-shortfall-runtime-20260608T182944/result.xml \
  tools/simulator/flows/maestro-perfect-set/flow_row23_budget_shortfall_runtime.yaml
```

Result: Maestro passed on `iPhone 16e - iOS 26.2` in `21s` with JUnit
`tests=1`, `failures=0`, and watchdog exit `0`. The script copied
`budget_independent_no_lpp_capacity_guard` and required the shortfall warning
while rejecting salary-only/product/provider/allocation fragments. Evidence:
`evidence/maestro-ci/row-23-budget-shortfall-runtime-20260608T182944/`.

Scope limit: Row 23x now has local widget proof plus simulator runtime
content proof for the shortfall branch. It still does not prove physical-device
VoiceOver/focus traversal, live backend/LLM scoring, production/staging
behavior, or full Budget/Rapport guidance parity with the audited Coach answer.
