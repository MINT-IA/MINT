description: Résumé du Plan 37, qui corrige le timeout CI des smoke tests BudgetContainerScreen.

# Plan 37 — Budget container CI repair summary

## Résultat

`BudgetContainerScreen` ne reste plus bloqué en chargement si `loadFromStorage()` échoue. Le fichier `indep_nav_remaining_smoke_test.dart` initialise maintenant `SharedPreferences`, ce qui évite les timeouts dans les smoke tests du shard `Flutter screens`.

## Changements

- `apps/mobile/lib/screens/budget/budget_container_screen.dart` : `loadFromStorage()` est encadré par `try/finally`.
- `apps/mobile/test/screens/indep_nav_remaining_smoke_test.dart` : ajout de `SharedPreferences.setMockInitialValues({})` en `setUp`.

## Vérification locale

- `flutter test test/screens/indep_nav_remaining_smoke_test.dart --plain-name 'BudgetContainerScreen renders without crashing (empty state)'` : réussi.
- `flutter test test/screens/indep_nav_remaining_smoke_test.dart --plain-name 'BudgetContainerScreen'` : réussi.
- `flutter test test/screens/indep_nav_remaining_smoke_test.dart --plain-name 'BudgetContainerScreen' test/screens/budget_screen_smoke_test.dart` : réussi.
- `flutter analyze lib/screens/budget/budget_container_screen.dart test/screens/indep_nav_remaining_smoke_test.dart` : réussi.

