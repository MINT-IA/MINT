# Phase 38 — Summary

## Result

Closed the P2 residues from the Claude Opus review.

## Changes

- Replaced internal `capitalViac` / `capitalFinpension` variable naming with
  neutral `capitalSecurities60` / `capitalSecurities80`.
- Removed the unused `isRecommended` branch and the recommended badge path from
  `Pillar3aComparatorWidget`.
- Replaced the highlighted copy `de plus à la retraite` with
  `d’écart estimé à la retraite`.
- Replaced the education text `Investir en actions (via VIAC)` with neutral
  3a titres language and explicit market-risk framing.
- Removed dead provider-specific 3a comparator ARB keys across six locales and
  regenerated Flutter localizations.
- Extended tests to reject provider mentions in the comparator and 3a education
  explanation.

## Files

- `apps/mobile/lib/widgets/comparators/pillar3a_comparator_widget.dart`
- `apps/mobile/lib/data/financial_explanations.dart`
- `apps/mobile/lib/l10n/app_*.arb`
- `apps/mobile/lib/l10n/app_localizations*.dart`
- `apps/mobile/test/data/financial_explanations_test.dart`
- `apps/mobile/test/widgets/comparators/pillar3a_comparator_widget_test.dart`
