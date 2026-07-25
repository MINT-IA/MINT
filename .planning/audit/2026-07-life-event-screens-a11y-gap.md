---
date: 2026-07-25
status: Finding — partial fix landed, root collapse NOT yet resolved
description: "Trois écrans life-event premium (invalidité, décès-proche, déménagement-cantonal) rendent mais leur sous-arbre d'accessibilité s'effondre côté iOS (classe ILLOG-02) : Maestro — et VoiceOver — ne lisent presque rien. On a ajouté le contrat screen-root Semantics(container+explicitChildNodes) (nécessaire, test-épinglé) mais il est INSUFFISANT seul : un rebuild sim échoue TOUJOURS les assertions texte. Cause profonde restante (SliverAppBar gradient / hero merged semantics) à traiter."
related:
  - tools/simulator/flows/parcours_secondaires.yaml
  - apps/mobile/test/screens/life_event_premium_a11y_test.dart
  - apps/mobile/test/screens/rente_vs_capital_semantics_test.dart
---

# Finding a11y — écrans life-event premium (classe ILLOG-02)

## TLDR

Trois écrans premium (`/invalidite`, `/life-event/deces-proche`, `/life-event/demenagement-cantonal`) **rendent visiblement** mais Maestro ne matche AUCUNE ancre texte — même symptôme que la régression documentée **ILLOG-02** (RenteVsCapitalScreen : « rend des pixels mais arbre d'accessibilité ~vide », `idb ui describe-all` = 1 élément). C'est donc un **vrai gap a11y** (VoiceOver concerné), pas un simple caprice Maestro. **Fix partiel livré** : les 3 écrans portent désormais le contrat screen-root `Semantics(container:true, explicitChildNodes:true)` (miroir du fix RvC `rente_vs_capital_screen.dart:684-687`), épinglé par `life_event_premium_a11y_test.dart` (RED sans le wrapper → GREEN avec). **MAIS insuffisant** : un app seedée reconstruite échoue TOUJOURS `.*lacune.*` sur invalidite (2026-07-25, écran visiblement rendu). L'effondrement résiduel est plus profond.

## Ce qui est confirmé

- Symptôme = classe ILLOG-02 (cf. `rente_vs_capital_semantics_test.dart` en-tête) : sous-arbre de route effondré sur le bridge a11y iOS.
- Les 3 écrans n'avaient PAS le contrat screen-root (les écrans sains budget/mon_argent/rvc l'ont). Ajouté maintenant.
- Le wrapper screen-root seul **ne suffit pas** à restaurer l'observabilité Maestro (donc pas non plus VoiceOver) : sim rebuild + re-run = toujours FAILED sur invalidite.

## Cause profonde restante (à investiguer — bead dédié)

Candidats : le `_buildAppBar` à `SliverAppBar`/`FlexibleSpaceBar` gradient (invalidite) porte peut-être sa propre `Semantics` sans `explicitChildNodes` qui ré-effondre son sous-arbre ; ou un `MergeSemantics`/`ExcludeSemantics` implicite dans `mint_hero_number` / cartes stylées. À trancher avec `debugDumpSemanticsTree` **côté device** (le tree Dart est peuplé — la collapse est bridge-iOS) ou VoiceOver device.

## Ce qui est livré ce bead (honnête)

1. Contrat screen-root Semantics sur les 3 écrans (correct a11y, aligne sur les écrans sains, test-épinglé). **N'affirme PAS** résoudre l'observabilité complète.
2. Les 3 écrans restent **exclus** de `parcours_secondaires.yaml` (toujours non observables).
3. Ce doc = résultat négatif clair : wrapper seul insuffisant.

## Data gaps

- Cause exacte de l'effondrement résiduel non confirmée au niveau code (nécessite un dump semantics device).
- Bénéfice VoiceOver du wrapper screen-root non mesuré directement (Maestro toujours KO ⇒ probablement pas encore lisible ; à confirmer device).
