---
date: 2026-07-25
status: Finding
description: "Trois écrans life-event premium (invalidité, décès-proche, déménagement-cantonal) RENDENT correctement mais n'exposent AUCUN texte à l'arbre d'accessibilité iOS — Maestro (et donc VoiceOver) ne peut rien y lire. Gap d'accessibilité (rule-9) découvert par le harnais sim."
related:
  - tools/simulator/flows/parcours_secondaires.yaml
  - .planning/decisions/2026-07-24-campagne-contenu-officiel-garanti.md
---

# Finding a11y — écrans life-event premium non lisibles par l'accessibilité iOS

## TLDR

En construisant les preuves sim des parcours secondaires (2026-07-25), trois écrans se sont révélés **impossibles à asserter par Maestro** alors qu'ils **rendent visiblement** (screenshots à l'appui) : `/invalidite` (DisabilityGapScreen), `/life-event/deces-proche` (DecesProcheScreen), `/life-event/demenagement-cantonal` (DemenagementCantonalScreen). Plusieurs ancres distinctes (titre, hero, section, CHF) ont toutes échoué contre des écrans visiblement rendus. Comme Maestro lit l'arbre d'accessibilité iOS, cela signifie que **VoiceOver ne peut pas lire ces écrans non plus** — un vrai gap d'accessibilité (rule-9 / EnhancedConfidence n'est pas en cause ici, c'est l'a11y du rendu).

## Preuves

- **invalidite** : screenshot montre « 1 personne sur 5 », « Comprendre ta lacune invalidité », chips « CHF 9'500 » / « CHF 25'872 ». Ancres testées et **échouées** : `.*personne sur 5.*`, `.*lacune.*`, `.*CHF.*`.
- **deces-proche** : screenshot montre « Urgences : premières 48 heures », liste numérotée, « Fortune estimée du défunt CHF 77'616 ». Ancres testées et **échouées** : `.*proche.*` (titre), `.*Urgences.*` (section body).
- **demenagement-cantonal** : non atteint (flow tronqué), mais même famille d'écran premium (hero MintHeroNumber + SliverAppBar gradient) → même risque.

## Contraste (écrans qui exposent bien leur texte)

Les écrans à onglets / standards exposent leur texte normalement et passent : `/concubinage`, `/expatriation`, `/segments/frontalier`, ainsi que tous les parcours core déjà prouvés (Travail #1024, Famille #1025, Logement+Succession #1026). Le problème est spécifique aux écrans « premium hero » (SliverAppBar à gradient + MintHeroNumber + cartes stylées).

## Hypothèse de cause (à investiguer)

Probable `MergeSemantics` / `ExcludeSemantics` implicite, un `Semantics(header: true)` qui masque le sous-arbre, ou un rendu texte custom (RichText/CustomPaint) qui n'expose pas de label plain-text. À vérifier dans les widgets partagés `mint_hero_number.dart`, `mint_result_hero_card.dart`, et les `_buildAppBar` à FlexibleSpaceBar de ces écrans.

## Impact & suivi

- **Impact** : utilisateurs VoiceOver ne peuvent pas lire ces écrans → exclusion de fait des personnes malvoyantes sur ces parcours. Sérieux pour une app de « lucidité financière ».
- **Suivi (bead séparé)** : auditer les widgets hero premium + ajouter des `Semantics(label:)` explicites ou retirer le `ExcludeSemantics`, puis ré-inclure ces 3 écrans dans `parcours_secondaires.yaml`.

## Data gaps

- Non confirmé au niveau code que c'est bien `ExcludeSemantics`/`MergeSemantics` (hypothèse). Le screenshot prouve le rendu ; la cause exacte reste à confirmer dans le code des widgets hero.
- `demenagement-cantonal` non testé directement (inféré par similarité) — à confirmer.
