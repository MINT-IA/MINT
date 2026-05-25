description: Plan 37 répare le shard Flutter screens après le chargement asynchrone de BudgetContainerScreen.

# Plan 37 — Budget container CI repair

## Contexte

La CI du SHA `2879025d` a échoué dans le job `Flutter screens`. Les quatre échecs venaient de `BudgetContainerScreen` dans `indep_nav_remaining_smoke_test.dart` : le test utilisait `pumpAndSettle`, tandis que le conteneur lançait désormais une restauration `SharedPreferences` non initialisée dans ce harness.

## Objectif

Stabiliser le comportement produit et le test harness :

- le conteneur sort du chargement même si la restauration locale échoue ;
- le smoke test initialise `SharedPreferences` avant chaque test.

## Vérification prévue

- `flutter test test/screens/indep_nav_remaining_smoke_test.dart --plain-name 'BudgetContainerScreen'`
- `flutter test test/screens/indep_nav_remaining_smoke_test.dart --plain-name 'BudgetContainerScreen renders without crashing (empty state)'`
- `flutter test test/screens/indep_nav_remaining_smoke_test.dart --plain-name 'BudgetContainerScreen' test/screens/budget_screen_smoke_test.dart`
- `flutter analyze lib/screens/budget/budget_container_screen.dart test/screens/indep_nav_remaining_smoke_test.dart`

