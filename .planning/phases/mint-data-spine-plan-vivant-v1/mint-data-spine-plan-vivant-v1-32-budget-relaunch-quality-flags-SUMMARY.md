description: Résumé Plan 32 — les flags de qualité budget survivent au relancement.

# Plan 32 — Summary

## Changements
- Ajout de `apps/mobile/test/data/budget/budget_local_store_test.dart`.
- `BudgetLocalStore.loadInputs()` passe par `BudgetInputs.fromMap`.
- `BudgetInputs.fromMap` relit `emergency_fund_months`.

## Résultat
Le budget local ne perd plus `isTaxEstimated`, `isHealthEstimated`, `isOtherFixedMissing` ni `emergencyFundMonths` après un save/load.

## Vérification
- `cd apps/mobile && flutter test test/data/budget/budget_local_store_test.dart`
