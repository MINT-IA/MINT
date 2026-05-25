description: Plan 36 étend le flow Maestro Mon Argent pour couvrir la relance directe /budget.

# Plan 36 — Budget direct relaunch Maestro

## Contexte

Les tests widget prouvent que `/budget` recharge les inputs persistés. Il manquait la preuve simulateur iPhone : sauvegarder un budget, relancer l'app sans effacer l'état, puis ouvrir `/budget` directement.

## Objectif

Étendre le flow Maestro Mon Argent + Budget pour couvrir la relance directe de l'écran budget détaillé.

## Portée

- Ajouter la sauvegarde du budget dans `flow_mon_argent_budget_setup_spine.yaml`.
- Relancer l'app avec `clearState: false`.
- Ouvrir `mintapp:///budget`.
- Vérifier `budget_screen` et `budget_data_quality_banner`.
- Conserver les captures dans `.planning/_walker`.

## Vérification prévue

- `flutter build ios --simulator --no-codesign ...`
- `xcrun simctl install booted apps/mobile/build/ios/iphonesimulator/Runner.app`
- `maestro test tools/simulator/flows/maestro-perfect-set/flow_mon_argent_budget_setup_spine.yaml --output .planning/_walker/maestro-evidence-20260525T0950-plan36`

