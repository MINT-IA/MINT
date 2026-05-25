description: Plan 63 prouve en simulateur que l'opener coach 3a affiche le plafond en format suisse.

# Summary — Plan 63 Maestro 3a Format Runtime Proof

## Fait

- Build iOS simulator relance sur le code Plan 62 avec archetype Julien.
- App installee sur iPhone 17 Pro iOS 26.2.
- Flow Maestro Mon Argent -> Budget setup -> Budget relaunch -> Coach rejoue
  sur build frais.

## Verifie

- `CODE_SIGNING_ALLOWED=NO flutter build ios --simulator --no-codesign --debug --dart-define=MINT_E2E_ARCHETYPE=julien_swiss --dart-define=MINT_DISABLE_BETA_MODAL=true`
  -> build passe.
- `xcrun simctl install booted apps/mobile/build/ios/iphonesimulator/Runner.app`
  -> install passe.
- `flow_mon_argent_budget_setup_spine.yaml` via watchdog Maestro
  -> `1/1 Flow Passed in 37s`.
- Artefacts :
  `.planning/walker/maestro-flows/coach-3a-format-plan63/20260525T154300Z/`.

## Observations runtime

- Budget relaunch affiche des montants plausibles :
  - revenu net `CHF 5'379`
  - logement `CHF 2'200`
  - LAMal `CHF 420`
  - disponible `CHF 2'239`
- Les valeurs absurdes signalees precedemment ne sont pas visibles :
  `19'272'200`, `420'420`.
- Coach opener affiche :
  `Ton 3a : CHF 0 cette annee. Jusqu'a 7'258 CHF encore deductibles.`

## Reste

- Continuer l'audit des autres montants injectes dans les messages coach.
- Ajouter une phase dediee aux scenarios avec contribution 3a non nulle, car
  le scenario actuel prouve le plafond restant mais pas encore une trajectoire
  de cotisation deja engagee.
