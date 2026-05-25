description: Plan 34 recharge le budget local quand l'utilisateur ouvre /budget directement après relance.

# Plan 34 — Budget direct relaunch

## Contexte

Le budget pouvait être restauré depuis `BudgetLocalStore` quand l'utilisateur passait par `Mon Argent`, mais l'ouverture directe de `/budget` ne lançait pas ce chargement. Cette différence créait un risque clair : les données existaient localement, mais l'écran détaillé affichait encore l'état vide.

## Objectif

Faire de `BudgetContainerScreen` le point de restauration du budget détaillé, afin que `/budget` soit autonome après relance.

## Portée

- Ajouter un test widget qui persiste des `BudgetInputs`, ouvre `BudgetContainerScreen`, puis attend `BudgetScreen`.
- Charger `BudgetProvider.loadFromStorage()` dans `BudgetContainerScreen`.
- Afficher un squelette pendant le chargement local.
- Ne pas modifier le modèle budget ni les chaînes i18n.

## Vérification prévue

- `flutter test test/screens/budget_screen_smoke_test.dart --plain-name 'BudgetContainerScreen restores saved inputs on direct open'`
- `flutter test test/screens/budget_screen_smoke_test.dart test/data/budget/budget_local_store_test.dart test/screens/budget_setup_screen_test.dart`
- `flutter analyze lib/screens/budget/budget_container_screen.dart test/screens/budget_screen_smoke_test.dart`

