# Summary 39 — Budget implausible amount guard

## Outcome

Budget capture now has a three-layer guard against implausible monthly charges:
the setup screen rejects them before persistence, the profile rebuild ignores
them, and budget input derivation drops stale values.

## Changes

- `BudgetSetupScreen` selects all text on tap and rejects monthly charges above
  local capture caps.
- `BudgetInputs` centralizes monthly caps for housing, health insurance, and
  other fixed charges.
- `CoachProfile.fromWizardAnswers` uses the same caps when rebuilding
  `DepensesProfile`.
- Added localized validation copy for the budget setup screen.
- Documented the capture guard in `docs/data-flow.md`.

## Verification

- `flutter test test/screens/budget_setup_screen_test.dart test/domain/budget/budget_service_test.dart test/services/coach_profile_wizard_test.dart`
- `flutter analyze lib/screens/budget/budget_setup_screen.dart lib/domain/budget/budget_inputs.dart lib/models/coach_profile.dart test/screens/budget_setup_screen_test.dart test/domain/budget/budget_service_test.dart test/services/coach_profile_wizard_test.dart`
- `python3 tools/checks/arb_parity.py`
- `python3 tools/checks/prefer_mint_color_token.py`
- `python3 tools/checks/prefer_mint_text_style.py`
- `python3 tools/checks/prefer_mint_fonts.py`
- `python3 tools/checks/prefer_mint_radius.py`
- `python3 tools/checks/prefer_mint_cta.py`
- `python3 tools/checks/accent_lint_fr.py --file docs/data-flow.md`
- MCP banned-term check on the new French validation copy and docs paragraph.
- `bash tools/simulator/maestro_env.sh test tools/simulator/flows/maestro-perfect-set/flow_mon_argent_budget_setup_spine.yaml --format junit --output .planning/_walker/maestro-evidence-20260525T103909-plan39/maestro.xml`

## Evidence

- `.planning/_walker/maestro-evidence-20260525T103909-plan39/maestro.log` —
  `1/1 Flow Passed in 34s`.
- `.planning/_walker/maestro-evidence-20260525T103909-plan39/mon-argent-02-budget-setup.png` —
  fields show CHF 2'200 housing and CHF 420 LAMal, not appended values.
- `.planning/_walker/maestro-evidence-20260525T103909-plan39/mon-argent-03-budget-direct-relaunch.png` —
  direct `/budget` relaunch renders CHF 2'200 housing and CHF 420 LAMal.
