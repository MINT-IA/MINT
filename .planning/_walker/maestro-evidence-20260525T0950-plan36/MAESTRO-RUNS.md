description: Preuve Maestro du flow Mon Argent, Budget setup et relance directe /budget.

# Maestro run — Plan 36

## Commande

```bash
maestro test tools/simulator/flows/maestro-perfect-set/flow_mon_argent_budget_setup_spine.yaml --output .planning/_walker/maestro-evidence-20260525T0950-plan36
```

## Résultat

Le flow s'est terminé avec code de sortie `0`.

## Assertions couvertes

- `mon_argent_screen`
- `mon_argent_data_spine_summary`
- `mon_argent_situation_map`
- `mon_argent_trajectory_map`
- `mon_argent_budget_summary`
- `mon_argent_budget_flow_bar`
- `mon_argent_patrimoine_summary`
- `budget_setup_screen`
- `budget_housing_field`
- `budget_lamal_field`
- `budget_setup_live_total`
- `budget_setup_save_button`
- `budget_setup_chat_fallback`
- relance app sans effacer l'état
- ouverture directe `mintapp:///budget`
- `budget_screen`
- `budget_data_quality_banner`

## Captures

- `mon-argent-01-data-spine.png`
- `mon-argent-02-budget-setup.png`
- `mon-argent-03-budget-direct-relaunch.png`

