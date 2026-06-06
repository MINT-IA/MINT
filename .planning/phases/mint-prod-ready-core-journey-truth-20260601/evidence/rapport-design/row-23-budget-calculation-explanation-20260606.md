# Row 23 — Budget Calculation Explanation — 2026-06-06

## Scope

Follow-up to CJT-047 after the Row 22 Budget income-copy runtime proof.
The runtime screenshots showed a confusing split:

- `/budget/setup` displayed `Total fixe : 2620 CHF / mois` for the fields
  entered in the form.
- `/budget` then rendered a higher fixed-charge formula because the final
  budget also includes profile-derived tax provision, known debts, and other
  fixed-charge data.

This was a user-truth/design issue, not a calculation-engine failure.

## Change

- Budget setup live total now says `Postes saisis ici : ...`, not `Total fixe`.
- A visible helper explains that the final budget may also include estimated
  taxes, known debts, and data already present in the profile.
- Budget hero/method copy now names the full subtraction set: fixed charges,
  estimated taxes, known debts, other fixed charges, and planned savings.
- Non-French locales avoid leaking `LAMal` in general method copy.
- The helper has a stable semantic anchor: `budget_setup_live_total_hint`.

## Mechanical Proof

Commands run after the fix:

```bash
cd apps/mobile
flutter gen-l10n
flutter test test/screens/budget_setup_screen_test.dart test/screens/budget_screen_smoke_test.dart test/domain/budget/budget_service_test.dart test/domain/budget/present_budget_builder_test.dart
flutter test test/services/navigation/screen_registry_test.dart test/services/navigation/route_planner_test.dart
flutter analyze

cd ../..
python3 tools/checks/arb_parity.py
./tools/mint-routes check
python3 tools/checks/cjt_context_guard.py
python3 tools/checks/maestro_locator_audit.py
git diff --check
```

Results:

- Budget/domain/widget suite: `124` tests passed.
- Navigation suite: `107` tests passed.
- `flutter analyze`: no issues.
- ARB parity: `6` locales, `6873` keys each.
- LSFin banned-term and French accent checks: clean.
- Route parity: `145` routes OK after known exemptions.
- Maestro locator audit: `44` flows scanned, `469` locators, all resolve.
- Claude CLI final review: `NO BLOCKERS`.

## User-Visible Outcome

The setup screen no longer implies that the entered form total is the final
fixed-charge truth. The final budget screen is now explicit about the broader
cashflow formula, including estimated tax and known-debt layers.

## Remaining Gaps

This closes CJT-047 locally. It does not close Row 22 or Row 23:

- Row 22 still needs broader clean primary-screen release proof.
- Row 23 still needs Coach/Rapport runtime accessibility and focus proof.
- A fresh runtime screenshot crawl should be rerun once the current build is
  installed for release-quality evidence.
