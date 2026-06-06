description: Row 23/CJT-063 local proof that independent/no-LPP report guidance separates the legal 3a ceiling from monthly budget capacity.

# Row 23 - Independent No-LPP Budget Capacity Guidance

## Scope

This evidence covers the `independent_no_lpp_income_reality` report action in
`/rapport`.

The issue addressed here is qualitative: the action already asked the user to
verify AVS-independent status, taxable income, liquidity, risk cover, optional
LPP, and cash reserves, but it did not explicitly separate two different
questions:

- the legal/tax 3a ceiling estimated from declared income and no-LPP status;
- the user's monthly budget capacity to absorb a contribution.

That separation matters for Row 23 and CJT-063 because a Swiss independent
person can have legal room without having sustainable monthly cashflow.

## Change

- `reportActionDesc3aIndependentNoLpp` now says MINT estimates the `plafond 3a`
  from declared income and the no-LPP assumption.
- The same description states that this legal ceiling does not prove the
  monthly budget can absorb a contribution.
- Step 2 now verifies the declared activity income used for the 3a ceiling,
  and taxable income separately for the tax impact.
- Step 3 now tests monthly budget capacity against income volatility.
- The same copy was updated in FR/EN/DE/ES/IT/PT and regenerated through
  `flutter gen-l10n`.

## Red/Green Proof

Red proof:

```bash
cd apps/mobile
flutter test test/services/financial_report_service_test.dart \
  --plain-name '3a priority action gives independent no-LPP verification guidance'
```

Before the copy change, this failed because the action did not contain
`plafond`.

Green proof:

```bash
cd apps/mobile
flutter test test/services/financial_report_service_test.dart \
  --plain-name '3a priority action gives independent no-LPP verification guidance'
```

Result: `All tests passed`.

Impact proof:

```bash
cd apps/mobile
flutter test \
  test/services/financial_report_service_test.dart \
  test/screens/advisor_banking_smoke_test.dart \
  test/services/pdf_service_test.dart
```

Result: `157/157` passed.

## Boundaries

This does not close Row 23 or CJT-063.

Still open:

- runtime VoiceOver/AX traversal proof;
- natural-language Coach answer scoring for the same persona;
- restart/provenance proof for income and status facts;
- broader per-archetype report quality scoring.
