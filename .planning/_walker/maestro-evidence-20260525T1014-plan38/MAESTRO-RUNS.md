description: Évidence Maestro du Plan 38 pour la boucle Mon Argent, Budget, relance directe et retour au chat.

# Maestro — Plan 38

## Commande

```bash
maestro test tools/simulator/flows/maestro-perfect-set/flow_mon_argent_budget_setup_spine.yaml --output .planning/_walker/maestro-evidence-20260525T1014-plan38
```

## Environnement

- Simulateur : iPhone 17 Pro, iOS 26.2.
- Bundle : `ch.mint.app`.
- Build : `flutter build ios --simulator --no-codesign` avec `MINT_E2E_ARCHETYPE=julien_swiss` et `MINT_DISABLE_BETA_MODAL=true`.

## Résultat

Exit code `0`.

Le flow a vérifié :

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
- relance directe `/budget` avec `budget_screen` et `budget_data_quality_banner`
- retour `/coach/chat` avec `coach_chat_screen`, `coach_input_field`, `coach_lightning_menu_button`, `coach_send_button`

## Captures

- `mon-argent-01-data-spine.png`
- `mon-argent-02-budget-setup.png`
- `mon-argent-03-budget-direct-relaunch.png`
- `mon-argent-04-coach-return.png`
