---
date: 2026-07-25
status: Finding
description: "Sur DEUX écrans life-event premium testés (invalidité, décès-proche), Maestro ne parvient à matcher AUCUNE de leurs ancres texte alors qu'ils rendent visiblement — gap d'OBSERVABILITÉ sim confirmé. VoiceOver n'est PAS prouvé cassé (les widgets hero portent un Semantics(label)) : c'est un RISQUE a11y à vérifier directement. Déménagement-cantonal : NON testé (inféré). Ne pas surestimer."
related:
  - tools/simulator/flows/parcours_secondaires.yaml
  - .planning/decisions/2026-07-24-campagne-contenu-officiel-garanti.md
---

# Finding — observabilité sim des écrans life-event premium (+ risque a11y à vérifier)

## TLDR

En construisant les preuves sim des parcours secondaires (2026-07-25), **deux** écrans premium testés se sont révélés **impossibles à asserter par Maestro** alors qu'ils **rendent visiblement** (screenshots) : `/invalidite` (DisabilityGapScreen) et `/life-event/deces-proche` (DecesProcheScreen). Plusieurs ancres texte distinctes ont toutes échoué. **Ce qui est confirmé** = un gap d'**observabilité** (Maestro ne matche pas le texte de ces écrans). **Ce qui n'est PAS prouvé** = que VoiceOver échoue : `mint_hero_number.dart:28-29` porte un `Semantics(label: '$value — $caption')`, donc un label existe ; le problème Maestro vient plausiblement d'une **fusion de sémantique** (un seul label agrégé au lieu de nœuds texte matchables), pas d'une absence de sémantique. `/life-event/demenagement-cantonal` n'a **pas** été testé (inféré par similarité, à confirmer).

## Ce qui est confirmé (2 écrans testés)

- **invalidite** : rend « 1 personne sur 5 », « Comprendre ta lacune invalidité », chips « CHF 9'500 » / « CHF 25'872 » (screenshot). Ancres Maestro testées et **échouées** : `.*personne sur 5.*`, `.*lacune.*`, `.*CHF.*`.
- **deces-proche** : rend « Urgences : premières 48 heures », « Fortune estimée du défunt CHF 77'616 » (screenshot). Ancres **échouées** : `.*proche.*` (titre), `.*Urgences.*` (section body).

→ Conclusion **sûre** : Maestro ne peut pas asserter sur ces deux écrans (gap d'observabilité de test). Les 3 écrans concubinage/expatriation/frontalier, eux, exposent leur texte et passent.

## Ce qui n'est PAS confirmé (à ne pas surestimer)

- **VoiceOver KO** : NON prouvé. Les widgets hero (`mint_hero_number.dart`) ont un `Semantics(label:)` explicite → VoiceOver lit probablement au moins le label agrégé. Le risque a11y est **réel mais à vérifier directement** (VoiceOver sur device, ou dump de l'arbre sémantique Flutter `debugDumpSemanticsTree` / `flutter test` avec `SemanticsHandle`).
- **Cause exacte** : hypothèse = sémantique fusionnée / label agrégé (les sous-textes ne sont plus des nœuds matchables). NON confirmée au niveau code.
- **demenagement-cantonal** : **NON testé**. Inféré par similarité de famille d'écran uniquement.

## Suivi (bead séparé)

1. Vérifier directement l'a11y : dump `debugDumpSemanticsTree` de invalidite + deces (et tester demenagement), ou VoiceOver device.
2. Si nœuds texte réellement non exposés → ajouter des `Semantics(label:)` granulaires (ou retirer une fusion) sur les widgets hero premium, puis ré-inclure les écrans dans `parcours_secondaires.yaml`.
3. Sinon (label agrégé suffisant pour VoiceOver) → traiter comme un simple gap d'observabilité Maestro (ex. exposer un `id`/testTag stable) et non un bug a11y.

## Data gaps

- Équivalence « Maestro ne matche pas » ⇏ « VoiceOver ne lit pas » : c'est justement le point à trancher.
- demenagement non exercé.
- Cause code non confirmée (hypothèse de fusion sémantique seulement).
