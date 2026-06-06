# Row 23 - Budget disclosure semantics

## Scope

Follow-up to the Row 23 `/budget` accessibility review. The calculation-detail
disclosure was visually correct, but its semantic control wrapped the expanded
formula content.

## Problem

`budget_calculation_detail_toggle` was the outer `Semantics` node for the whole
disclosure. Once expanded, the button owned the detail subtree, including
`budget_flow_map` and `budget_formula_proof`.

This made the structure weaker for assistive technology: the control and the
content were available, but the control was not a clean header-only disclosure
node.

## Fix

- Moved `budget_calculation_detail_toggle` semantics to the header control only.
- Kept the expanded calculation content as sibling semantic nodes.
- Added regression assertions:
  - collapsed toggle is tap-enabled and `expanded=false`;
  - expanded toggle is a button, tap-enabled, `expanded=true`;
  - label remains `Détail du calcul`;
  - label does not absorb formula labels such as `Revenu net` or `Charges`;
  - toggle has zero traversal children;
  - `budget_flow_map` and `budget_formula_proof` remain separate anchors.

## Verification

```bash
flutter test test/screens/budget_screen_smoke_test.dart --plain-name "BudgetScreen exposes Maestro semantics anchors"
# 1/1 pass

flutter test test/screens/budget_screen_smoke_test.dart test/accessibility/primary_screen_dynamic_type_test.dart test/widgets/budget/spending_meter_test.dart
# 23/23 pass

flutter analyze
# No issues found.

python3 tools/checks/mint_quality_os_check.py
python3 tools/checks/cjt_context_guard.py
python3 tools/checks/maestro_locator_audit.py
./tools/mint-routes check
git diff --check
# all OK
```

## Residual Risk

This is widget-level semantic structure proof. It does not replace full
VoiceOver traversal evidence for Row 23, so Row 23 remains `PARTIAL`.
