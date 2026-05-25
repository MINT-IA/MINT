description: Résumé du Plan 31, qui ajoute un flow Maestro Mon Argent / Budget Setup.

# Plan 31 — Résumé

## Changements

- Ajout de `flow_mon_argent_budget_setup_spine.yaml`.
- Le flow vérifie les ancres `Mon Argent`.
- Le flow vérifie la saisie déterministe logement + LAMal dans `BudgetSetupScreen`.
- Le flow capture deux screenshots d'évidence.

## Vérification locale

- `flutter build ios --simulator --no-codesign ...`
- `xcrun simctl install booted build/ios/iphonesimulator/Runner.app`
- `MAESTRO_STALL_THRESHOLD=60 MAESTRO_HARD_LIMIT=300 bash tools/simulator/maestro_with_watchdog.sh test tools/simulator/flows/maestro-perfect-set/flow_mon_argent_budget_setup_spine.yaml` → exit `0`

## Evidence

- `.planning/_walker/20260525T083329`
- `.planning/_walker/maestro-evidence-20260525T0833/MAESTRO-RUNS.md`
