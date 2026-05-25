description: Plan 62 formate le plafond 3a des openers coach en style suisse.

# Plan 62 — Coach 3a Opener CHF Format

## Pourquoi

Le Plan 61 a prouvé que le budget runtime ne produit plus les valeurs absurdes
signalées, mais la capture coach montre encore `7258 CHF`. Pour une fintech
suisse, le chiffre doit être lisible et cohérent avec le reste de l'app :
`7'258 CHF`.

## Scope

- Corriger les openers 3a live produits par `DataDrivenOpenerService`.
- Corriger la résolution des insights pré-calculés sans changer les valeurs
  brutes stockées en cache.
- Ajouter des tests ciblés pour deadline 3a et savings opportunity.

## Hors scope

- Ne pas modifier les plafonds réglementaires.
- Ne pas changer la phrase ARB ni la sémantique fiscale.
- Ne pas toucher aux autres langues dans cette phase.

## Vérification

- `flutter test test/services/coach/data_driven_opener_service_test.dart test/services/coach/precomputed_insights_service_test.dart`
- `flutter analyze` sur les deux services et deux tests touchés.
