description: Plan 61 prouve en simulateur que Mon Argent, Budget et Coach restent cohérents après le câblage data-spine.

# Plan 61 — Maestro Budget Coach Runtime Proof

## Pourquoi

Les tests unitaires prouvent les contrats, mais pas l'expérience réelle. Les
régressions critiques vues dans Mint sont souvent runtime : mauvais séparateur
de milliers, champ concaténé, budget restauré avec une valeur impossible, ou
chat qui ne voit pas les données pourtant présentes ailleurs.

## Scope

- Construire et installer un build iOS simulateur avec l'archetype
  `julien_swiss`.
- Exécuter le flow Maestro `flow_mon_argent_budget_setup_spine.yaml`.
- Vérifier explicitement les garde-fous anti-valeurs absurdes :
  `19'272'200` et `420'420` doivent être absents.
- Capturer les artefacts dans `.planning/walker/maestro-flows/`.
- Conclure si le résultat est une preuve utilisable ou un bug à corriger.

## Hors scope

- Ne pas modifier le moteur budget sans échec reproductible.
- Ne pas étendre le flow aux arbitrages dans cette phase.
- Ne pas tester le round-trip LLM long ; cette phase valide le chemin
  Mon Argent → Budget → Coach et les chiffres locaux.

## Vérification

- `flutter build ios --simulator --debug --dart-define=MINT_E2E_ARCHETYPE=julien_swiss --dart-define=MINT_DISABLE_BETA_MODAL=true`
- `xcrun simctl install booted apps/mobile/build/ios/iphonesimulator/Runner.app`
- `bash tools/simulator/maestro_with_watchdog.sh test tools/simulator/flows/maestro-perfect-set/flow_mon_argent_budget_setup_spine.yaml --output <result.xml> --format junit`
