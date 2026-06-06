---
description: Row 23 local semantics traversal proof for independent/no-LPP Budget and Rapport surfaces.
linked_rows: [23]
---

# Row 23 - Budget/Rapport Semantics Traversal Contract

## Scope

Local Flutter accessibility contract for `independent_no_lpp_income_reality` on
`/budget` and `/rapport`. This is not a runtime VoiceOver walkthrough.

`test/semantics_test_helpers.dart` exposes a shared traversal helper that flattens the
semantics tree with `DebugSemanticsDumpOrder.traversalOrder`.

```text
budget_screen -> budget_data_quality_banner -> budget_hero_summary
-> budget_calculation_detail_toggle -> budget_flow_map -> budget_formula_proof
report_synthesis_summary -> report_compliance_summary
-> report_disclaimer_summary
```

The tests also assert:

- `/rapport` keeps independent/no-LPP guidance: `statut AVS d’indépendant`,
  `revenu net imposable`, and no `ouvrir` / `fintech` product framing.
- `/rapport` primary CTA `Commencer` remains a semantic tap action.
- `/budget` says `Revenu net`, `Charges`, `Futur`, `Disponible`, and does not
  regress to `Salaire net` or `Budget retraite`.

The first implementation idea based on `SemanticsNode.rect.top` was rejected:
scroll-view semantics geometry is not a stable traversal oracle.

## Verification

```bash
cd apps/mobile
flutter test test/screens/budget_screen_smoke_test.dart test/screens/advisor_banking_smoke_test.dart
flutter test test/screens/budget_screen_smoke_test.dart test/screens/advisor_banking_smoke_test.dart test/accessibility/primary_screen_dynamic_type_test.dart
flutter analyze
cd ../..
python3 tools/checks/mint_quality_os_check.py && python3 tools/checks/cjt_context_guard.py
python3 tools/checks/maestro_locator_audit.py && ./tools/mint-routes check && git diff --check
```

Results: targeted Budget/Rapport suite `63/63` passed; Row 23 dynamic-type
impact suite `70/70` passed; analyze and all listed guards passed.

## Remaining Work

Row 23 remains `PARTIAL`: this proves local traversal order, not iPhone 16e
runtime VoiceOver/AX traversal, broader PDF visual QA, Coach natural-language
quality, or persona-flow rescoring.
