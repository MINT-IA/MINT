description: Résumé du Plan 34, qui rend /budget capable de restaurer les inputs budget persistés.

# Plan 34 — Budget direct relaunch summary

## Résultat

`BudgetContainerScreen` recharge maintenant `BudgetProvider` depuis `BudgetLocalStore` à l'initialisation. Si des inputs budget existent déjà, l'ouverture directe de `/budget` affiche le détail budget au lieu de l'état vide.

## Changements

- `apps/mobile/lib/screens/budget/budget_container_screen.dart` : passage en `StatefulWidget`, appel à `loadFromStorage()`, état de chargement avec `MintLoadingSkeleton`.
- `apps/mobile/test/screens/budget_screen_smoke_test.dart` : test de relance directe avec `BudgetLocalStore`, `BudgetContainerScreen`, bannière qualité et revenu restauré.

## Vérification locale

- `flutter test test/screens/budget_screen_smoke_test.dart --plain-name 'BudgetContainerScreen restores saved inputs on direct open'` : réussi.
- `flutter test test/screens/budget_screen_smoke_test.dart test/data/budget/budget_local_store_test.dart test/screens/budget_setup_screen_test.dart` : réussi.
- `flutter analyze lib/screens/budget/budget_container_screen.dart test/screens/budget_screen_smoke_test.dart` : réussi.

## Suite

Le prochain cran logique est de renforcer le lien chat ↔ budget : le coach doit recevoir les mêmes faits structurés que les écrans utilisent, puis proposer des actions qui renvoient vers les écrans déjà ancrés pour Maestro.

