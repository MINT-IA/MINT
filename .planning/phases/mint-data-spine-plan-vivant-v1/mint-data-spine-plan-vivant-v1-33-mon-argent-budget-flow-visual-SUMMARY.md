description: Résumé Plan 33 — la carte budget de Mon Argent affiche un flux visuel testable.

# Plan 33 — Summary

## Changements
- Ajout de `_BudgetFlowBar` dans `BudgetSummaryCard`.
- Ajout de `apps/mobile/test/widgets/mon_argent_budget_summary_card_test.dart`.
- Ajout de l'ancre Maestro `mon_argent_budget_flow_bar`.
- Mise à jour du flow `tools/simulator/flows/maestro-perfect-set/flow_mon_argent_budget_setup_spine.yaml`.

## Résultat
`Mon Argent` donne maintenant un signal visuel immédiat : part consommée par les dépenses et part restante, sans changer les données ni les calculs.

## Vérification
- `cd apps/mobile && flutter test test/widgets/mon_argent_budget_summary_card_test.dart`
