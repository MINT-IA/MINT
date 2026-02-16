# ADR-CH-BUDGET-MVP: Budget Module & Emergency Fund

## Status
Accepted

## Context
Nous devons implémenter la fonctionnalité "Budget/Emergency Fund" comme capability MVP Immediate (This Year).
L'objectif est d'aider l'utilisateur à comprendre son disponible ("Just Available") ou à gérer ses dépenses courantes (méthode "Envelopes").
Cela doit respecter les contraintes de Read-Only, Offline-first, et Safe Mode.

## Decision
Nous allons implémenter un module `budget` isolé dans l'application mobile Flutter.

### 1. Domain Model
Le calcul se fera côté client (Mobile) pour l'instant, car offline-first.
- **Inputs**: `payFrequency`, `netIncome`, `housingCost`, `debtPayments`, `budgetStyle`.
- **Outputs**: `available`, `variables` envelope, `future` envelope.
- **Invariant**: `available = income - housing - debt`.

### 2. Budget Styles
Deux modes supportés :
1.  **Just Available**: Affiche simplement le reste à vivre après charges fixes.
2.  **Envelopes (3)**: Répartit le disponible entre "Variables" (courses, loisirs) et "Futur" (épargne, projets). L'utilisateur peut ajuster via des sliders.

### 3. Safe Mode
Si `hasDebt` est vrai, le système détectera une situation de dette potentielle.
Le rapport (Advisor Report) inclura obligatoirement une recommandation liée à la dette si celle-ci est déclarée, conformément au Safe Mode SOT.

### 4. Persistence
Les réponses aux questions (Inputs) seront stockées dans `Session.answers` (Map<String, dynamic>) pour flexibilité et conformité OpenAPI (additionalProperties).
Les overrides locaux (réglages des sliders) seront stockés dans un `BudgetRepository` local (SharedPreferences ou base locale simple), séparé de la Session qui est immutable/snapshot par nature une fois le rapport généré, mais ici on parle modélisation "vibe" rapide.
*Correction*: Pour le MVP, les inputs sont dans la Session. Les overrides (l'état des sliders) seront persistés localement (`BudgetLocalStore`) pour que l'utilisateur retrouve ses réglages.

## Consequences
- **Positif**: Pas de dépendance backend complexe immédiate. Calculs instantanés. Pédagogique.
- **Négatif**: Pas de sync multi-device pour l'état des sliders (local only pour l'instant).
- **Compliance**: Wording strict "Aide à la décision", pas de promesse.

## Technical Components
- `BudgetService`: Pure logic.
- `BudgetInputs` / `BudgetPlan`: Data classes.
- `BudgetScreen`: UI interactive.
- `BudgetSection` in Report: Static summary equivalent.
