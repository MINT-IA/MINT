description: Plan 30 ajoute des ancres Semantics.identifier aux surfaces centrales Mon Argent et Budget.

# Plan 30 — Money surface semantics

## Objectif

Rendre les surfaces centrales de situation financière et de budget testables par Maestro sur iOS avec des ancres structurelles.

## Portée

- `MonArgentScreen`
- `BudgetSummaryCard`
- `PatrimoineSummaryCard`
- `BudgetScreen`
- `BudgetSetupScreen`

## Contrat d'ancrage

- `mon_argent_screen`
- `mon_argent_data_spine_summary`
- `mon_argent_situation_map`
- `mon_argent_trajectory_map`
- `mon_argent_budget_summary`
- `mon_argent_patrimoine_summary`
- `budget_screen`
- `budget_data_quality_banner`
- `budget_hero_summary`
- `budget_flow_map`
- `budget_setup_screen`
- `budget_housing_field`
- `budget_lamal_field`
- `budget_setup_live_total`
- `budget_setup_save_button`
- `budget_setup_chat_fallback`

## Vérification

- Ajouter les tests widget avant le code.
- Lancer les tests ciblés Mon Argent / Budget.
- Lancer `flutter analyze` sur le périmètre.
