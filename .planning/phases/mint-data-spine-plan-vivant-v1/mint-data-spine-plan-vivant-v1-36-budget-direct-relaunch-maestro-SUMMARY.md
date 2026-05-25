description: Résumé du Plan 36, qui ajoute une preuve Maestro pour la relance directe /budget.

# Plan 36 — Budget direct relaunch Maestro summary

## Résultat

Le flow Maestro Mon Argent + Budget couvre maintenant la sauvegarde du budget, une relance sans effacer l'état, puis l'ouverture directe de `mintapp:///budget`.

## Changements

- `tools/simulator/flows/maestro-perfect-set/flow_mon_argent_budget_setup_spine.yaml` : ajout sauvegarde, relance app, ouverture `/budget`, assertions `budget_screen` et `budget_data_quality_banner`.
- `.planning/_walker/maestro-evidence-20260525T0950-plan36/` : preuves du run et captures.

## Vérification locale

- `flutter build ios --simulator --no-codesign --dart-define=API_BASE_URL=https://mint-staging.up.railway.app/api/v1 --dart-define=MINT_E2E_ARCHETYPE=julien_swiss --dart-define=MINT_DISABLE_BETA_MODAL=true` : réussi.
- `xcrun simctl install booted apps/mobile/build/ios/iphonesimulator/Runner.app` : réussi.
- `maestro test tools/simulator/flows/maestro-perfect-set/flow_mon_argent_budget_setup_spine.yaml --output .planning/_walker/maestro-evidence-20260525T0950-plan36` : réussi, code de sortie `0`.

## Suite

Continuer avec le lien coach ↔ budget structuré, en gardant la même discipline : test pur, écran, puis Maestro quand le flux utilisateur change.

