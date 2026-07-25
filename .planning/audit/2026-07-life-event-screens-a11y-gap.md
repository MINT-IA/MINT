---
date: 2026-07-25
status: Finding — necessary a11y boundary landed, observability NOT restored
description: "Sur DEUX écrans premium testés (invalidité, décès-proche), Maestro ne matche AUCUNE ancre texte alors qu'ils rendent — gap d'OBSERVABILITÉ (même symptôme observé qu'ILLOG-02). On a ajouté le contrat screen-root Semantics(container+explicitChildNodes) aux 3 écrans (nécessaire, test-épinglé). Post-wrapper, SEUL invalidité a été re-testé sur sim : échoue toujours. décès/déménagement non re-testés post-wrapper ; déménagement jamais testé du tout. Impact VoiceOver NON mesuré (risque, pas un fait)."
related:
  - tools/simulator/flows/parcours_secondaires.yaml
  - apps/mobile/test/screens/life_event_premium_a11y_test.dart
  - apps/mobile/test/screens/rente_vs_capital_semantics_test.dart
---

# Finding a11y — observabilité des écrans life-event premium

## TLDR

Deux écrans premium **testés** (`/invalidite`, `/life-event/deces-proche`) **rendent visiblement** mais Maestro n'a matché AUCUNE de leurs ancres texte — même **symptôme observé** que la régression ILLOG-02 (RenteVsCapitalScreen : Maestro/`idb` lisaient ~1 élément sur un écran rendu). C'est confirmé comme un gap d'**observabilité** (Maestro/arbre a11y iOS). **Ce qui n'est PAS mesuré** = VoiceOver : je n'ai PAS testé VoiceOver ; « Maestro ne matche pas » n'établit pas « VoiceOver ne lit pas ». On a ajouté le contrat screen-root `Semantics(container:true, explicitChildNodes:true, identifier)` aux 3 écrans (miroir du fix RvC `rente_vs_capital_screen.dart:684-687`), épinglé par `life_event_premium_a11y_test.dart` (RED sans wrapper → GREEN avec). **Post-wrapper, seul `invalidite` a été re-testé sur sim reconstruit : `.*lacune.*` échoue toujours.** `deces-proche` et `demenagement-cantonal` n'ont PAS été re-testés post-wrapper (et `demenagement` n'a jamais été exercé, même pré-wrapper).

## Périmètre exact des preuves (ne pas généraliser)

| Écran | Maestro pré-wrapper | Maestro post-wrapper | VoiceOver |
|---|---|---|---|
| invalidite | testé → FAIL (3 ancres) | **re-testé → FAIL** (`.*lacune.*`) | **non mesuré** |
| deces-proche | testé → FAIL (2 ancres) | non re-testé | non mesuré |
| demenagement-cantonal | **jamais testé** (inféré) | non testé | non mesuré |

## Ce qui est confirmé

- Sur invalidite + deces : Maestro ne matche pas leur texte alors qu'ils rendent (screenshots). Symptôme = classe ILLOG-02 (observabilité).
- Le contrat screen-root Semantics manquait sur les 3 écrans (les écrans sains budget/mon_argent/rvc l'ont). Ajouté.
- Sur invalidite re-testé post-wrapper : le wrapper screen-root seul ne restaure PAS l'observabilité Maestro.

## Ce qui n'est PAS confirmé

- Impact VoiceOver : **non mesuré** sur aucun des 3 écrans. Risque plausible (Maestro lit l'arbre a11y iOS) mais non établi.
- Observabilité post-wrapper de deces + demenagement : **non re-testée**.
- Cause profonde de l'effondrement résiduel : hypothèse (SliverAppBar gradient / merged hero semantics), non confirmée code.

## Suivi (bead dédié)

1. Mesurer directement : `debugDumpSemanticsTree` device et/ou VoiceOver sur device, pour les 3 écrans. (Hypothèse par analogie ILLOG-02 : le tree Dart serait peuplé et la collapse serait côté bridge-iOS — NON mesuré ici, à confirmer.)
2. Identifier l'effondrement résiduel (probable Semantics sans explicitChildNodes plus bas, ex. `_buildAppBar` SliverAppBar ou hero).
3. Une fois observables → ré-inclure dans `parcours_secondaires.yaml`.

## Ce qui est livré ce bead (honnête)

- Contrat screen-root Semantics sur les 3 écrans (correct, aligne sur les écrans sains, test-épinglé). Le test vérifie que le nœud identifiant existe et a des labels descendants — une **précondition nécessaire**, PAS une preuve que l'écran est entièrement lisible.
- 3 écrans **restés exclus** du flow sim (toujours non observables).
- Ce doc = périmètre de preuve exact + résultat négatif (wrapper seul insuffisant sur invalidite).
