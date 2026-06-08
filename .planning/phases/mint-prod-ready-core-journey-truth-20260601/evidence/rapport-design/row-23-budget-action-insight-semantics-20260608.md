---
description: Row 23 local proof that Budget next-action semantics keep independent/no-LPP context without duplicated CTA text.
status: verified-local
date: 2026-06-08
linked_bug: CJT-063
---

# Row 23 - Budget Action Insight Semantics

## Scope

This is a focused Row 23 / `CJT-063` local accessibility and guidance-depth
proof for the `independent_no_lpp_income_reality` persona.

It proves the Budget next-action widget exposes the independent/no-LPP context,
CTA, impact, and tap action once in the widget semantics tree. It does not
prove real VoiceOver speech or physical-device focus traversal.

Row 23 remains `PARTIAL`.

## Problem

The Budget next-action card already rendered the independent/no-LPP context and
impact on screen. A TDD check showed its semantics label also included those
pieces, but duplicated the CTA text:

- `Voir l’écart`
- context about no-LPP disability coverage limited to AI;
- `Voir l’écart` again;
- `comprendre le gap ~70 %`.

That duplication is a local accessibility defect: assistive technology could
hear the command twice, making the Budget guidance feel less deliberate.

## Change

`ActionInsightWidget` now builds one explicit semantics label from:

- non-empty context line;
- action line;
- optional impact line.

The parent `Semantics` uses `excludeSemantics: true`, so child `Text` widgets
do not re-add the same CTA label. The same local tap handler is wired to both
`Semantics.onTap` and `InkWell.onTap`, so the semantics node remains an
actionable button.

The Row 23 Budget widget test now asserts that the independent/no-LPP action
semantics:

- keeps the no-LPP/AI context;
- keeps the CTA `Voir l’écart`;
- keeps the `~70` impact;
- contains `Voir l’écart` exactly once;
- exposes `SemanticsAction.tap`.

The base Budget smoke test also asserts the fallback action card remains a
single actionable semantics button with the expected fallback label when no
`CoachProfileProvider` is present.

## Verification

Red proof:

```bash
cd apps/mobile
flutter test test/screens/budget_screen_smoke_test.dart --plain-name "BudgetScreen independent no-LPP semantics traverse cashflow"
```

Expected failure before the fix:

- `RegExp('Voir l’écart').allMatches(actionInsight.label).length` was `2`,
  expected `1`.

Green proof:

```bash
cd apps/mobile
flutter test test/screens/budget_screen_smoke_test.dart --plain-name "BudgetScreen independent no-LPP semantics traverse cashflow"
flutter test test/screens/budget_screen_smoke_test.dart --plain-name "BudgetScreen smoke test - renders correctly"
flutter test test/screens/budget_screen_smoke_test.dart test/screens/advisor_banking_smoke_test.dart
flutter test test/services/e2e_runtime_flags_test.dart test/screens/budget_screen_smoke_test.dart test/screens/advisor_banking_smoke_test.dart
flutter analyze lib/widgets/action_insight_widget.dart test/screens/budget_screen_smoke_test.dart
flutter analyze
cd ..
python3 -m json.tool .planning/phases/mint-prod-ready-core-journey-truth-20260601/flow-evidence-registry.json >/dev/null
python3 -m json.tool .planning/phases/mint-prod-ready-core-journey-truth-20260601/persona-flow-benchmark.json >/dev/null
python3 -m json.tool .planning/phases/mint-prod-ready-core-journey-truth-20260601/quality-os-scorecard.json >/dev/null
python3 tools/checks/mint_quality_os_check.py
python3 tools/checks/cjt_context_guard.py
python3 tools/checks/maestro_locator_audit.py
./tools/mint-routes check
git diff --check
```

Results:

- focused Budget test: pass;
- fallback Budget smoke test: pass;
- Budget/Rapport smoke suite: `70/70` pass;
- E2E flags + Budget/Rapport smoke suite: `72/72` pass;
- targeted analyze: no issues.
- full `flutter analyze`: no issues;
- JSON, Quality OS, CJT context, Maestro locator, route parity, and diff
  whitespace checks: pass.

## Remaining CJT-063 Work

Still required before closing `CJT-063`:

- physical-device VoiceOver/focus traversal proof for Coach, `/budget`, and
  `/rapport`;
- live backend/LLM scoring for the same independent/no-LPP persona;
- deeper Budget/Rapport guidance around optional LPP, AVS-independent status,
  risk cover, liquidity, and income volatility;
- production/staging path proof for the same updated profile facts.
