description: Plan 64 aligne le format CHF du contexte Budget Vivant injecte au coach.

# Plan 64 — Coach Context CHF Format

## Pourquoi

Le Plan 63 prouve que l'opener visible affiche `7'258 CHF`, mais l'audit
statique montre que le contexte Budget Vivant du coach construit encore des
montants en interpolation brute, par exemple `CHF ${amount.round()}/mois`.
Ce contexte nourrit le LLM : il doit porter les memes chiffres lisibles que les
ecrans.

## Scope

- Ajouter un test cible sur `ContextInjectorService.buildContext`.
- Formater les montants Budget Vivant avec le formatter CHF suisse existant.
- Garder les valeurs sources et les calculs inchanges.

## Hors scope

- Ne pas modifier les calculs BudgetSnapshot.
- Ne pas modifier les textes visibles des ecrans.
- Ne pas toucher au backend ni aux arbitrages.

## Verification

- RED puis GREEN :
  `flutter test test/services/context_injector_service_test.dart`
- `flutter analyze lib/services/coach/context_injector_service.dart test/services/context_injector_service_test.dart`
