description: Plan 32 ferme le drift de persistance des indicateurs de qualité budget au relancement.

# Plan 32 — Budget relaunch quality flags

## Objectif
Conserver les indicateurs de qualité du budget entre l'enregistrement, le stockage local et le relancement.

## Contexte
`BudgetInputs.toMap()` écrivait les flags `meta_*`, mais `BudgetLocalStore.loadInputs()` reconstruisait l'objet avec un parseur parallèle qui les ignorait. Résultat : après relancement, l'écran Budget pouvait perdre les signaux "estimé" ou "à compléter".

## Critères
- Ajouter un test de round-trip local pour les flags budget.
- Réutiliser le parseur canonique `BudgetInputs.fromMap`.
- Préserver aussi `emergencyFundMonths`, qui était écrit sous `emergency_fund_months`.

## Vérification
- `cd apps/mobile && flutter test test/data/budget/budget_local_store_test.dart`
