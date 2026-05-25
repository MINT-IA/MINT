description: Plan 63 prouve en runtime Maestro que l'opener 3a affiche un montant CHF formate suisse.

# Plan 63 — Maestro 3a Format Runtime Proof

## Pourquoi

Le Plan 62 a corrige le format `7258 CHF` en `7'258 CHF` dans les services
coach. Comme le bug initial a ete vu sur simulateur, la preuve attendue doit
etre runtime : build iOS simulator, install, flow Maestro, screenshots.

## Scope

- Reconstruire l'app iOS simulator avec l'archetype E2E Julien.
- Rejouer un flow Maestro qui passe par Mon Argent, Budget et Coach.
- Verifier que les captures ne montrent plus `7258 CHF` et que le coach affiche
  `7'258 CHF`.

## Hors scope

- Ne pas modifier les plafonds 3a.
- Ne pas retoucher la logique fiscale.
- Ne pas elargir aux arbitrages dans cette phase.

## Verification

- `CODE_SIGNING_ALLOWED=NO flutter build ios --simulator --no-codesign --debug --dart-define=MINT_E2E_ARCHETYPE=julien_swiss --dart-define=MINT_DISABLE_BETA_MODAL=true`
- `xcrun simctl install booted apps/mobile/build/ios/iphonesimulator/Runner.app`
- `tools/simulator/maestro_with_watchdog.sh test tools/simulator/flows/maestro-perfect-set/flow_mon_argent_budget_setup_spine.yaml`
