description: Plan GSD pour nettoyer Mon argent/Budget sans ajouter une nouvelle couche de données.

# Phase mon-argent-money-map-v1 — Plan

## Goal

Rendre `Mon argent` et `Budget mensuel` cohérents, pédagogiques et actionnables
en consolidant les read models existants plutôt qu'en ajoutant une nouvelle
couche.

## Scope

1. Corriger le chemin `/budget` pour préférer le profil canonique quand il est
   disponible.
2. Ajouter des tests de cohérence qui empêchent `budget_inputs_v1` de battre
   `CoachProfile`.
3. Réduire la redondance visible du budget en gardant une seule hiérarchie
   mensuelle claire.
4. Préparer la refonte `Mon argent` en onglets autour des concepts utilisateur:
   aujourd'hui, mois, patrimoine, prévoyance, futur.
5. Rejouer les tests Flutter ciblés puis le flow Maestro budget quand le crash
   runtime est stabilisé.

## Non-goals

- Pas de nouveau store persistant.
- Pas de nouveau moteur de calcul financier.
- Pas de refonte globale de navigation.
- Pas de conseil personnalisé; les projections restent conditionnelles et
  sourcées.

## Execution Slices

### Slice 1 — Canonical Budget Entry

- `BudgetContainerScreen` lit `CoachProfileProvider.profile` si présent.
- Si un profil existe, `BudgetProvider.refreshFromProfile(profile)` prime sur
  `BudgetLocalStore.loadInputs()`.
- Si aucun profil n'est chargé, le cache legacy reste le fallback.
- Test: un cache stale à CHF 8'000 ne doit pas s'afficher si le profil indique
  un autre budget.

### Slice 2 — Budget UI Simplification

- Garder le hero disponible + une décomposition.
- Mettre les preuves/formules et la pédagogie avancée sous une section
  secondaire/repliable.
- Sortir l'action insight du premier viewport budget; elle appartient à
  `Mon argent`.

### Slice 3 — Mon Argent Information Architecture

- Transformer `Mon argent` en segmented control:
  - Aujourd'hui: liquidité/marge actionnable.
  - Mois: budget résumé.
  - Patrimoine: actifs, dettes, net, liquidité.
  - Prévoyance: AVS, LPP, 3a avec statut connu/estimé/manquant.
  - Futur: trajectoire A -> B.
- Réutiliser `DataSpineSnapshot`, `BudgetSnapshot`, `PatrimoineAggregator`.
- Executed: the screen now renders one selected section at a time and Maestro
  verifies tab switching before continuing to budget setup.

### Slice 4 — Runtime Proof

- Tests Flutter ciblés.
- `flutter analyze` sur fichiers touchés.
- Maestro `flow_mon_argent_budget_setup_spine.yaml` avec assertions anti-valeurs
  absurdes.

## Verification

- PASS — `flutter test test/screens/budget_setup_screen_test.dart test/screens/budget_screen_smoke_test.dart`
- PASS — `flutter test test/screens/mon_argent_screen_test.dart test/screens/budget_setup_screen_test.dart test/screens/budget_screen_smoke_test.dart`
- PASS — `flutter analyze lib/providers/coach_profile_provider.dart lib/app.dart lib/screens/budget/budget_container_screen.dart lib/screens/budget/budget_screen.dart lib/screens/budget/budget_setup_screen.dart test/screens/budget_setup_screen_test.dart test/screens/budget_screen_smoke_test.dart`
- PASS — `flutter analyze lib/screens/mon_argent/mon_argent_screen.dart test/screens/mon_argent_screen_test.dart`
- PASS — `flutter gen-l10n`
- PASS — ARB parity MCP check, 6 locales with 6817 keys each
- PASS — `flutter build ios --simulator --debug --no-codesign --dart-define=MINT_E2E_ARCHETYPE=julien_swiss --dart-define=MINT_DISABLE_BETA_MODAL=true`
- PASS — `bash tools/simulator/maestro_with_watchdog.sh test tools/simulator/flows/maestro-perfect-set/flow_mon_argent_budget_setup_spine.yaml --output .planning/walker/maestro-flows/mon-argent-money-map-v1/result.xml --format junit` (latest: 41s)
- PASS — `python3 tools/checks/wiki_lint.py lint` with no FAIL-level violations

## Acceptance Criteria

- `/budget` n'affiche pas un cache budget stale quand un profil canonique est
  disponible.
- `Mon argent` et `/budget` ne peuvent plus afficher deux marges mensuelles
  issues de sources différentes pour le même profil.
- Le premier viewport budget ne répète pas la même formule sous deux formes.
- Le parcours utilisateur répond clairement à: ce que j'ai, ce qui est liquide,
  ce qui est lié, ce que je dépense, où je vais, quelle action vient ensuite.
