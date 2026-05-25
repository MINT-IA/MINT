description: Plan 64 aligne les montants CHF du contexte Budget Vivant injecte au coach.

# Summary — Plan 64 Coach Context CHF Format

## Fait

- `ContextInjectorService` utilise maintenant `formatChfWithPrefix` pour les
  montants Budget Vivant envoyes au coach.
- Les lignes concernees couvrent marge libre, charges fixes, revenu retraite,
  ecart mensuel et leviers mensuels.
- Un test cible verifie que les montants avec milliers arrivent au coach en
  format suisse, par exemple `CHF 9'876/mois`.

## Verifie

- RED attendu : le nouveau test voyait encore `CHF 9876/mois`.
- `flutter test test/services/context_injector_service_test.dart`
  -> 25 tests passes.
- `flutter analyze lib/services/coach/context_injector_service.dart test/services/context_injector_service_test.dart`
  -> no issues.

## Reste

- Continuer l'audit des autres chemins coach qui construisent encore des
  montants par interpolation manuelle.
- Prochaine phase recommandee : verifier les prompt templates et widgets coach
  qui exposent des montants avec suffixe `CHF` ou `/mois`.
