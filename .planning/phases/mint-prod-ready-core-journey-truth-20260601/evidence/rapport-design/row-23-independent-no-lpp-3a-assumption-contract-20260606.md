# Row 23 - Independent/no-LPP 3a Assumption Contract

Date: 2026-06-06
Rows touched: Row 23, Row 29
Bug: CJT-061
Status: Local calculation/content contract only

## What Was Wrong

`/rapport` had already stopped showing the static visible label
`Plafond 3a salarié`, but the report model still had two deeper risks:

- `UserProfile.isSalaried` only recognized `employee`, while MINT also uses
  `salarie`, `salarié`, and the e2e seed value `employed`.
- The 3a analysis used the absolute without-LPP ceiling for every non-salaried
  profile, instead of the income-based applicable ceiling for an independent
  without LPP.

That made the independent/no-LPP persona weak even after copy fixes. The UI
could be neutral while the calculation contract was still employee-shaped or
overstated.

## Swiss Rule Anchor

The official BSV/OFAS 3a page states the 2025/2026 frame as:

- CHF 7'258/year for a salaried person affiliated with a pension institution.
- 20% of income, capped at CHF 36'288/year, for an independent person not
  affiliated with a pension institution.

Source: https://www.bsv.admin.ch/fr/votre-cotisation-au-3e-pilier

## What Changed

- `UserProfile.isSalaried` now normalizes the active status dialects:
  `employee`, `employed`, `salaried`, `salarie`, and `salarié`.
- `FinancialReportService` now computes an applicable 3a ceiling from the
  profile:
  - with LPP: `pillar3a.max_with_lpp`;
  - without LPP: `20%` of captured annual profile income, capped at
    `pillar3a.max_without_lpp`.
- `simulationAssumptions` now exposes the status-aware fields:
  `pillar3a_lpp_status`, `pillar3a_max_applicable`,
  `pillar3a_max_with_lpp`, `pillar3a_max_without_lpp`, and
  `pillar3a_without_lpp_income_rate`.
- The old ambiguous `pillar3a_max` assumption key is not emitted for this
  report path.

## Proof

Commands passed locally:

```bash
cd apps/mobile
flutter analyze lib/services/financial_report_service.dart lib/models/financial_report.dart test/services/financial_report_service_test.dart test/screens/advisor_banking_smoke_test.dart
flutter test test/services/financial_report_service_test.dart
flutter test test/screens/advisor_banking_smoke_test.dart
```

Observed result:

- Analyzer: no issues.
- `financial_report_service_test.dart`: 84 tests passed.
- `advisor_banking_smoke_test.dart`: 44 tests passed.

New/updated assertions:

- `self_employed` / `independant` no longer receive the salaried 3a ceiling.
- Independent without LPP receives an income-based applicable ceiling, not the
  raw absolute max by default.
- High-income independent without LPP is capped at `pillar3a.max_without_lpp`.
- A salaried profile below the LPP entry threshold uses the without-LPP
  income-based room.
- `salarie`, `salarié`, `salaried`, and `employed` normalize as salaried for
  with-LPP report assumptions.
- `/rapport` screen smoke keeps the neutral assumption label and does not show
  the old `7’258` salaried ceiling under an independent fixture.

## Runtime Guidance Quality Review

Mechanical proof:

- Local model and widget tests prove the report data contract and visible
  neutral copy path for an independent fixture.

User-visible outcome:

- The report no longer has to choose between a neutral label and a wrong hidden
  assumption. The displayed 3a analysis is now backed by a status-aware
  applicable ceiling.

Guidance quality:

- MINT stays in guidance/simulation mode: it frames a ceiling and assumptions,
  not a product choice, provider ranking, or personalized financial advice.

Non-absurd:

- An independent/no-LPP user is no longer treated as a salaried LPP user or as
  automatically entitled to the full absolute without-LPP ceiling.

Inclusive:

- The contract handles salaried and independent dialects used by MINT today,
  including the French persisted values and the e2e fixture value.

Financial trust:

- The calculation now follows the BSV/OFAS public rule shape and records the
  applied assumption in `simulationAssumptions`.

Remaining qualitative gaps:

- No full Maestro persona-flow benchmark has run yet for
  `independent_no_lpp_income_reality`.
- The without-LPP income basis is still the captured profile income
  (`monthlyNetIncome * 12`) when no explicit AVS-determining independent
  income value is available.
- Full Row 23 remains `PARTIAL`: Coach/Rapport focus order, VoiceOver
  traversal, broader PDF visual QA, and per-archetype content scoring remain
  open.

## Claude CLI Review

Claude CLI final review returned `NO BLOCKERS` after checking the corrected
diff and the two Flutter suites.

Findings addressed before closure:

- Added high-income independent/no-LPP clamp coverage.
- Added salaried-below-LPP-threshold coverage.
- Added `salaried` and `salarié` dialect coverage.
- Reverted the persona-flow benchmark score inflation; CJT-061 now credits
  data/calculation truth only.
- Kept gross-up only for LPP-threshold and tax-estimate paths; without-LPP 3a
  room uses captured annual profile income.

Residual risks accepted for this local lot:

- A true AVS-determining independent-income field would be better than
  `monthlyNetIncome * 12`.
- The canonical runtime fixture for `independent_no_lpp_income_reality` is
  still missing.
