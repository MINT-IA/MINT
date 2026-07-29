---
description: Plan de la suite, version 2 — réécrit après quatre audits adversariaux (4,5/10 et 5/10 sur la v1). Ordonné par nuisance vérifiée, raccordé à la phase active, avec les contraintes du dépôt nommées et une ligne par bead ouvert.
---

# Plan de la suite — v2 (2026-07-27)

## Ce qui a changé depuis la v1, et pourquoi

La v1 a reçu quatre audits indépendants. Deux notes : **4,5/10** (lentille
produit) et **5/10** (lentille séquencement). Les défauts retenus, tous
vérifiables :

1. **Elle ignorait la phase active.** `mint-2-0-first-experience-rente-capital`
   est ouverte et porte un contrat produit plus fort qu'une file de tickets.
2. **Elle omettait les deux beads P1** sans dire pourquoi.
3. **Elle revendiquait un déblocage faux** : `maestro hierarchy` ne produit pas
   d'arbre VoiceOver, donc le chantier device ne ferme pas `jx6`.
4. **Elle gardait ouverte une question déjà tranchée par le code** : l'archétype
   couple existe (`coach_profile_seeds.dart:293`) ; c'est
   `toWizardAnswers()` qui écrit `q_household_type: 'single'` en dur ligne 235,
   pour tous les seeds.
5. **Son chiffre de 104 n'est produit par aucun outil du dépôt.** Trois nombres
   circulaient le même jour pour le même objet (4915 / 151 / 104).
6. **Le fichier lui-même échouait à `journey_os_check`.** Un plan qui ne passe
   pas le premier garde du dépôt n'a pas mesuré son terrain. Cette v2 est sous
   `.planning/architecture/`, préfixe autorisé.

Et surtout : deux relevés parallèles ont remonté **plus grave que tout ce que la
v1 listait**. Ils passent devant.

## Raccordement à la phase active

Ce plan **sert** `mint-2-0-first-experience-rente-capital`, il ne la remplace
pas. Son SPEC exige notamment (§7) que toute valeur financière visible porte
sa valeur ou plage, son unité, ses hypothèses, ses sources, sa complétude, ses
champs manquants et sa version de calcul. Le travail du 2026-07-26 construisait
ce contrat par morceaux sans le nommer. Les unités ci-dessous y sont rattachées
explicitement.

## Contraintes du dépôt qui mordent

Nommées ici parce que la v1 n'en citait aucune et que quatre vont se déclencher.

| Contrainte | Effet sur ce plan |
|---|---|
| `journey_os_check` — liste d'autorisation | Chaque PR touchant un fichier neuf doit y ajouter son chemin |
| `active_context_guard` — motifs de branche | `codex/journey-os-*` obligatoire |
| `phase_contract_guard` | La phase active reste `mint-2-0-first-experience-rente-capital` |
| `rules.md` — ASK FIRST | Ajouter une formule, une constante réglementaire ou une source de calcul demande Julien |
| Discipline dépôt public | Rédaction technique et neutre dans les PR ; pas de registre d'accusation |
| Budget de revue dynamique | `git diff --shortstat` justifié quand une verticale cohérente le dépasse |

---

## U0 — Les sorties actuellement fausses (interruptions de sûreté)

Trois classes, chacune vérifiée par moi et non par un rapport d'agent seul.

### U0.a — Attributions de source sur des tables façonnées

`services/backend/app/services/fiscal/wealth_tax_service.py:63` et son miroir
`apps/mobile/lib/services/wealth_tax_service.dart:25` portent
`EFFECTIVE_WEALTH_TAX_RATES_500K` avec le commentaire
`Source: OFS Charge Fiscale 2024`.

Mesure : **26 valeurs, strictement croissantes, zéro ex æquo.** Aucune série
fiscale réelle n'a cette forme — deux cantons finissent toujours par se croiser
à une décimale. De plus, l'office nommé ne publie pas ce document ; la charge
fiscale comparée est une publication de l'administration fédérale des
contributions.

Le point qui rend la classe grave : **les champs `sources` sont livrés à
l'écran** (`schemas/family.py`, `endpoints/life_events.py`, puis
`widgets/coach/response_card_widget.dart`). L'attribution n'est pas un
commentaire interne, elle s'affiche sous le nombre.

Même motif à vérifier sur : `CANTON_SOURCE_TAX_RATES` (24 cantons partagent le
même `base_rate` avec un multiplicateur), `LAMAL_PRIMES_MENSUELLES` (valeurs
toutes multiples de 10), `CANTON_MARGINAL_MULTIPLIERS` (source auto-référentielle).

**Critère mécanique.** Pour chaque table : soit une source primaire citée avec
sa date de collecte et sa méthode de vérification — le patron existe déjà dans
`cantonal_comparator.py:105`, qui documente une collecte API datée, un profil de
calibration et ses limites — soit l'attribution est retirée et remplacée par une
mention d'estimation explicite, sur le modèle de
`cantonal_benchmark_data.dart:114`. Test de non-régression qui échoue si une
`Map` indexée par canton porte une attribution officielle sans date de collecte.

### U0.b — Prescriptions de produit rendues à l'écran

Vérifié : `disability_countdown_widget.dart:295` rend
`'→ Souscris une APG privée (dès CHF 45/mois)'` — impératif, produit nommé, prix.
Le relevé en dénombre une vingtaine du même registre
(`segments_service.dart:817-843`, `independant_service.py:289-309`,
`gender_gap_service.py:308`, `wizard.py:331`…).

Cause structurelle : le `ComplianceGuard` est correctement écrit mais **n'est
câblé que sur les chemins LLM**. Tous les services déterministes produisent du
texte user-facing qui ne le traverse jamais.

**Critère mécanique.** Le garde s'applique aussi aux sorties déterministes, ou un
lint refuse l'impératif de souscription dans une chaîne rendue. Zéro occurrence
restante sur la liste établie, plus un test qui échoue si l'une réapparaît.

### U0.c — Le verrou de gate qui s'ouvre sur un fait vide

`userProvidedFields.contains('salary')` sans contrôle de valeur : un salaire à
zéro portant la clé déverrouille le calcul. Corrigé sur `naissance`, à vérifier
sur `first_job` et `donation` (bead `udu`).

**Pourquoi avant toute preuve device.** Prouver sur simulateur un gate qui peut
s'ouvrir à tort produirait une preuve verte sur un comportement faux — le pire
état possible sous protocole 0-TRUST.

---

## U1 — Rendre la preuve device possible, puis la produire

**Ce qui bloque, tranché et non plus « à trancher ».** L'archétype couple existe.
`toWizardAnswers()` écrit `q_household_type: 'single'` en dur pour tous les
seeds. Il manque un champ ménage sur `CoachProfileSeed` et sa propagation. Le
harnais d'injection existe (`MINT_E2E_ARCHETYPE`, employé par
`walker_audit_tap_render.sh`).

**Ce que cela ne débloque PAS.** Le bead `jx6` réclame une preuve **VoiceOver**,
et ses notes enregistrent un `Semantics` qui s'effondre sur le pont
d'accessibilité iOS pour un écran et pas pour un autre. Un `maestro hierarchy`
ne produit pas d'arbre d'accessibilité. `jx6` reste ouvert et demande une passe
VoiceOver humaine.

**Critère mécanique.** `tools/simulator/flows/couple_concubinage_gate.yaml`
commité ; `maestro test` exit 0 depuis une installation propre ; artefact
`hierarchy` commité sous `.planning/journeys/evidence/` contenant la liste
explicite d'identifiants attendus. Et un run de contrôle **avec un salaire seedé
à zéro** qui doit rester gaté — sinon U0.c n'est pas fermé.

---

## U2 — Câbler les gardes avant de drainer

Le dépôt a déjà résolu ce problème une fois : `no_hardcoded_fr --added-only`,
posé le 2026-07-26 avec sa justification écrite. Trois classes n'ont toujours
aucune barrière : accents français, séparateur de milliers suisse, plafonds
périmés côté Dart.

**Pourquoi avant le drainage.** Une campagne de correction sans garde revient en
quelques semaines. C'est l'histoire écrite en tête de `lefthook.yml`.

**Critère mécanique.** Chaque lint sort exit 1 sur une ligne ajoutée fautive,
exit 0 sur l'existant, et porte son `--self-test`.

---

## U3 — Une verticale de lucidité, pas un drainage horizontal

La v1 proposait de traduire 104 libellés en six langues. L'audit produit a
tranché : c'est du travail spéculatif tant que la verticale à distribuer n'est
pas choisie ni prouvée.

**À la place** : une verticale complète — celle de la phase active,
`2e pilier : rente ou capital` — menée jusqu'au bout du contrat SPEC §7, en
français puis en allemand, avec sa terminologie relue.

**Critère mécanique.** Pour cette verticale : chaque valeur affichée porte
plage, unité, hypothèses, sources datées, complétude, champs manquants et
version de calcul ; le résultat est retrouvable dans le dossier ; un test monte
l'écran en `Locale('de')` et échoue si une chaîne française est rendue.

**La règle de remplacement, issue de l'audit produit.** Tout chiffre retiré doit
être remplacé par au moins un objet utile : une comparaison directionnelle
défendable, une plage sourcée, un test de sensibilité, les variables qui font
basculer le résultat, le prochain document à récupérer, ou un scénario
paramétrable. « Le mécanisme » seul est trop vague. Détection du vidage : si
l'utilisateur ne peut ni nommer les deux ou trois variables dominantes, ni voir
ce qui changerait la conclusion, la verticale est devenue une fiche éducative.

---

## Les douze beads ouverts, chacun avec sa ligne

| Bead | Traitement |
|---|---|
| `mla` P1 — write-back conjoint | **Demande à Julien** : le volet A est une décision produit et de protection des données. Volet B suit. Non silencieux. |
| `t44` P1 — 11 constats conseiller | Fermé : #4, #5, #7, #9, #10, #11. Reste : #3 (partage LPP sans intérêts ni date de valorisation), #6 (fiscalité post-divorce), #8 (conditions caisse concubin). |
| `udu` P2 — verrou de gate | **U0.c**, avant toute preuve |
| `h7c` P2 — modèle marié 0.92 | U4, branche à choisir avant d'ouvrir la branche git ; « remplacer » = ASK FIRST |
| `fbz` P2 — divorce backend à taux plats | **Même verticale que `h7c`**, pas deux PR : les traiter séparément ferait diverger mobile et backend pendant l'intervalle |
| `ch8` P2 — réserve fausse pour donateur célibataire | U4 |
| `0jn` P2 — bande d'incertitude gender gap | **Reporté, motif** : `t44#10` dit que gender gap modélise le minimum légal et non le plan réel. Poser une bande autour d'un chiffre qui modélise le mauvais objet, c'est habiller une erreur. À traiter après #10. |
| `jx6` P2 — preuve VoiceOver | Reste ouvert. Demande une passe VoiceOver humaine, pas un flow Maestro. |
| `el8` P3 — bandes d'incertitude | Jumeau de `0jn`, même report, même motif |
| `mrd` P3 — clés `userProvidedFields` manquantes | Rattaché à U0.c, même mécanisme |
| `9fl` P3 — sémantique échelle 44 | Reporté : choix produit précision vs prudence, écart maximal ~21 CHF/mois dans le sens conservateur |
| `e05` P3 — cible de redesign | **Workstream parallèle**, décision déjà enregistrée (correctness d'abord). Nommé pour qu'il ne disparaisse pas. |

## Ce qui demande Julien

1. **`mla` volet A** — partage du profil financier du partenaire sous
   consentement bilatéral. Décision produit et protection des données.
2. **Recalibrage d'un moteur fiscal** sur une source primaire (`h7c`, `fbz`) —
   ASK FIRST par `rules.md`.
3. **Passe VoiceOver device** (`jx6`) — non substituable par un outil.

## Contre-arguments et données manquantes

- **« U0 retarde encore la valeur. »** U0 ne construit rien de neuf, il arrête
  des sorties actuellement fausses. C'est la seule catégorie dont le coût croît
  avec le temps d'exposition.
- **« La règle de remplacement va ralentir chaque retrait. »** Oui. C'est le
  prix pour ne pas transformer la doctrine « pas de chiffre indéfendable » en
  produit vide.
- **Donnée manquante : aucune télémétrie d'usage.** L'ordre de U3 et U4 repose
  sur le contrat de la phase active et sur un raisonnement, pas sur des données
  d'usage. Une intuition de Julien sur ce que les utilisateurs touchent
  réellement prime sur ce classement.
- **Donnée manquante : l'ampleur réelle de U0.a.** Les tables ont été qualifiées
  par leur *structure* — régularité arithmétique, arrondis, absence d'ex æquo —
  et non par comparaison ligne à ligne avec les publications officielles. Cette
  comparaison reste à faire pour mesurer l'écart.
