---
description: Row 23 proof that Budget secondary visuals use current cashflow wording instead of salary-only or retirement-only framing.
linked_rows: [22, 23]
---

# Row 23 - Budget Current Cashflow Copy

## Scope

Focused Row 23 follow-up on `/budget` populated state. The first-viewport
Budget copy was already income-inclusive, but two secondary visuals still
carried misleading labels:

- `Budget503020Widget` announced `Salaire net` in semantics.
- `BudgetSandwichChart` announced and displayed `Ton budget retraite`.

This was a product-quality issue, not cosmetic wording. The Budget surface is
the user's current monthly cashflow surface and must work for independent,
mixed-income, rent, allocation, and transition situations.

## Change

- `Budget503020Widget` now takes `netIncome` and announces `Revenu net`.
- `BudgetSandwichChart` now labels the surface as `Budget mensuel`.
- The `/budget` smoke test guards against reintroducing `Salaire net` and
  `Budget retraite` in the populated secondary visuals.
- The widget test guards the neutral `Revenu net` semantics label.

## Verification

```bash
cd apps/mobile
flutter test test/widgets/coach/budget_503020_widget_test.dart test/screens/budget_screen_smoke_test.dart
flutter test test/widgets/coach/budget_503020_widget_test.dart test/screens/budget_screen_smoke_test.dart test/accessibility/primary_screen_dynamic_type_test.dart
flutter analyze
cd ../..
git diff --check
python3 tools/checks/mint_quality_os_check.py
python3 tools/checks/cjt_context_guard.py
python3 tools/checks/maestro_locator_audit.py
./tools/mint-routes check
```

Results:

- Targeted Budget/widget suite: `24/24` passed.
- Impact Row 23 dynamic-type suite: combined run `31/31` passed.
- `flutter analyze`: no issues.
- MINT Quality OS, CJT guard, Maestro locator audit, route parity, and diff
  whitespace check: OK.
- MINT MCP text guards: no banned LSFin terms and no ASCII-flattened French
  accent patterns in the changed Budget copy.
- Claude CLI review: `No blockers`. It also flagged the existing hardcoded-FR
  i18n debt as a low-priority follow-up, not introduced by this patch.

## Remaining Work

This is local widget/smoke proof only. Row 23 remains `PARTIAL` until Budget
and Rapport have broader VoiceOver/focus traversal proof, runtime screenshot
review for more personas, broader PDF visual/page QA, and updated persona-flow
scoring.
