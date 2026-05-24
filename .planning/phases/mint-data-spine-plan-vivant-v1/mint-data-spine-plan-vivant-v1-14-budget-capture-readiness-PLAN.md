---
phase: mint-data-spine-plan-vivant-v1
plan: 14
type: tdd
depends_on:
  - mint-data-spine-plan-vivant-v1-13-situation-budget-capture-PLAN.md
files_modified:
  - apps/mobile/lib/models/coach_profile.dart
  - apps/mobile/lib/services/data_spine/data_spine_service.dart
  - apps/mobile/lib/screens/budget/budget_setup_screen.dart
  - apps/mobile/test/services/data_spine_service_test.dart
  - apps/mobile/test/screens/budget_setup_screen_test.dart
autonomous: true
---

# Plan 14 — Budget Capture Readiness

## Goal

Stop Mint from treating `CoachProfile.fromWizardAnswers` fallback values as
real budget facts. Budget readiness must distinguish explicit user data from
defaults, while keeping `BudgetSetupScreen` as the canonical fixed-charge
writer.

## Scope

- Track explicit budget/cash/debt fields in `CoachProfile.userProvidedFields`.
- Make `DataSpineService` expose housing, LAMal, cash, and debt only when
  explicit or from a trusted source.
- Treat explicit zero debt as known.
- Add a widget test proving `BudgetSetupScreen` writes canonical keys.

Out of scope: new routes, backend changes, budget engine rewrite, Maestro.

## TDD

1. Add failing data-spine tests:
   - missing budget keys do not count as known situation data;
   - explicit housing/LAMal + zero debt clear the situation gap.
2. Add failing budget setup writer test for:
   - `q_housing_cost_period_chf`
   - `q_lamal_premium_monthly_chf`
   - `q_pay_frequency = monthly`
   - `_coach_depenses_*` optional fixed charges.
3. Implement the minimum code to pass.

## Verify

```bash
cd apps/mobile && flutter test test/services/data_spine_service_test.dart test/services/data_spine_readiness_digest_service_test.dart test/screens/budget_setup_screen_test.dart
cd apps/mobile && flutter analyze lib/models/coach_profile.dart lib/services/data_spine/data_spine_service.dart lib/screens/budget/budget_setup_screen.dart test/services/data_spine_service_test.dart test/screens/budget_setup_screen_test.dart
python3 tools/checks/prefer_mint_cta.py --file apps/mobile/lib/screens/budget/budget_setup_screen.dart
python3 tools/checks/accent_lint_fr.py --file apps/mobile/lib/l10n/app_fr.arb
git -c core.whitespace=blank-at-eol,blank-at-eof,space-before-tab,cr-at-eol diff --check
```
