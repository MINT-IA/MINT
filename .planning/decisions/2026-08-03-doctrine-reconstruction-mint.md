---
date: 2026-08-03
status: Proposed
authors: Fable/Opus 5 (session de reprise), sur mandat de Julien
panel: fusion 3 sources (handoff 2026-08-03 · north-star 2026-07-31 · audit Fable 2026-08-03)
supersedes: —
superseded_by: —
description: Doctrine canonique de la reconstruction — fil rouge unifié North Star, anti-dérive v2 amendée, chaque batch finit par un runtime touchable.
related:
  - .planning/decisions/2026-07-31-north-star-experience.md
---

# Doctrine canonique de la reconstruction MINT

## TLDR

Un seul document fixe la doctrine de la reconstruction : le fil rouge 6 étapes fusionné avec la North Star expérience, les règles anti-dérive du handoff amendées par l'audit du 2026-08-03, et un gate non négociable — chaque batch finit par un runtime touchable, sinon le batch a échoué.

## Contexte

Trois sources, trois angles, un recouvrement d'environ 80 % qui exigeait une version unifiée :

1. **Le handoff de reconstruction** (`/Users/julienbattaglia/Desktop/MINT-HANDOFF-2026-08-03.md`) — fil rouge 6 étapes (§3), workflow A→I (§13), règles anti-dérive (§29), définition de « terminé » (§15). Il documente aussi la spirale Batch 19 : des cycles entiers de durcissement de gardes d'acceptation (isolation Python, bytecode, shadow imports) pendant lesquels aucune route produit n'a avancé.
2. **La North Star expérience** (`.planning/decisions/2026-07-31-north-star-experience.md`) — « le chiffre d'abord, le changement ensuite, la profondeur sur demande, la chaleur sans jugement — et l'app se souvient de toi » ; le retour est un rituel, l'évolution est visible, l'air est une structure.
3. **L'audit Fable du 2026-08-03** (session de reprise sur le handoff) — cinq amendements : les preuves s'exécutent en CI, seul exécuteur neutre ; un roast vérifie LE fix, il ne remet pas le monde à zéro ; le travail méta est plafonné à 20 % par batch ; l'inventaire se fait contre dev actuel, jamais contre un souvenir ; chaque batch finit par un runtime touchable — le battement produit est un rôle du lead.

À partir d'ici, ce document est LA référence à citer ; le handoff et la North Star restent les sources détaillées.

## Étoile du Nord

> **MINT est l'application suisse de lucidité financière qui apprend progressivement ta situation et te la rend : le chiffre d'abord, le changement ensuite, la profondeur sur demande, la chaleur sans jugement — et l'app se souvient de toi.**

## Le fil rouge canonique (6 étapes unifiées)

Chaque moment de l'application répond dans cet ordre. Une page sans provenance, rôle dans le parcours, entrée, sortie et preuve runtime n'existe pas.

1. **Ce que MINT sait** — un chiffre d'abord, avec provenance, date et niveau de confiance ; la profondeur vient en étages, sur demande, jamais tout d'un coup.
2. **Ce qui manque** — une seule demande utile à la fois, posée seulement au moment où la réponse change visiblement l'écran.
3. **Ce que cela change** — impact concret, en francs ou en décision ; au retour, le delta d'abord : le retour est un rituel (« depuis ton dernier passage… »), jamais la landing d'un inconnu.
4. **Pourquoi** — explication courte, pédagogique, chaleur sans jugement ; une idée par écran, l'air comme structure (espacement 8/16/24/40, deux idées au plus par viewport).
5. **La prochaine action** — une seule, petite, sûre, réversible.
6. **La sortie** — retour, correction, reprise plus tard, jamais de route morte ; et l'évolution reste visible : « toi d'avant vs toi maintenant », mesurée en compréhension, cumulative, qui ne régresse pas par simple inaction.

## Doctrine anti-dérive v2

Les règles §29 du handoff, amendées par l'audit. Chaque règle est impérative.

1. Traite un seul flow humain à la fois, en micro-batch borné.
2. Écris le contrat ou le test RED avant le runtime ; commite atomique et réversible.
3. Ne laisse aucune route morte, aucun service sans caller, aucune façade sans câblage.
4. N'affiche aucun chiffre sans provenance ; ne déploie aucun LLM sans golden eval.
5. Mets un feature flag et un kill switch sur tout chemin utilisateur nouveau.
6. **(amendé)** Fais exécuter les preuves par la CI, liées au SHA : la CI est le seul exécuteur neutre ; une preuve locale auto-attestée ne promeut rien.
7. **(amendé)** Un finding invalide l'acceptation du périmètre touché ; le roast suivant vérifie LE fix — il ne remet pas le monde à zéro.
8. **(nouveau)** Plafonne le travail méta (gardes, process, outillage) à 20 % d'un batch ; au-delà, le batch a dérivé.
9. **(nouveau)** Inventorie le legacy contre l'état actuel de dev, jamais contre un souvenir.
10. **(nouveau)** Termine chaque batch par un runtime touchable ; sinon le batch a échoué.
11. Ne crois jamais le résumé d'un agent : inspecte diff, Git, runtime et preuves.
12. Garde dev et main intacts hors du chemin PR ; ne merge rien sans CI verte et décision explicite.
13. **(nouveau)** Cercle herméneutique : chaque batch se clôt par deux questions dont mint-lead consigne les réponses dans une section « Herméneutique (règle 13) » du corps de la PR de clôture du batch — « qu'est-ce que ce batch révèle du tout ? » et « que doit réviser le tout ? » — où « le tout » désigne exactement trois artefacts : ce document, le contrat de navigation, l'inventaire réutilisable. « Aucune révision requise » y est une réponse valide ; quand une révision s'impose, son commit fait partie de la même PR. Vérification : la présence de la section se contrôle à la review de la PR ; un lint de présence est le gate candidat (follow-up outillage, comptabilisé dans le plafond méta de la règle 8). La mémoire de session sert d'entrée, l'artefact committé est la seule forme durable.

## Le workflow par batch (A→I condensé)

- **A. Cadrage** — un résultat humain en une phrase, des exclusions explicites, un owner.
- **B. Contrat d'expérience** — routes, états (vide/erreur/offline/correction/reprise), microcopy ; roast débutant/UX/finance/a11y avant le code.
- **C. Contrat de données et calcul** — provenance, unités, fixtures suisses, oracles, tests RED.
- **D. Threat/compliance borné** — classification des données, consentements, rétention, kill switch.
- **E. Implémentation verticale** — le minimum de code qui réalise le flow, flag désactivé, aucun widget sans consommateur.
- **F. Vérification** — la CI exécute les preuves (tests, oracles, parité ARB 6 langues, walkthrough) liées au SHA ; critique croisée Codex ; un finding → fix → re-vérification du fix (règle 7).
- **G. Validation humaine légère** — 3 à 5 minutes de Julien, 1 à 3 questions de compréhension.
- **H. Release progressive** — interne → TestFlight restreint → canary sous flag → élargissement après fenêtre stable.
- **I. Exploitation** — Sentry, métriques produit et confiance, mise à jour des règles suisses avec provenance.

**Gate de sortie non négociable : le batch se termine par un runtime touchable** — un build ou un sim où le flow se tape au doigt, lié au SHA. Un batch qui ne produit que des artefacts (gardes, contrats, docs, tests) sans surface touchée a échoué, quelle que soit la qualité de ces artefacts. Les batches doc/outillage assumés existent, mais ils comptent dans le plafond méta de la période, pas comme des batches produit.

## Rôles et vérification

- **Zéro confiance, symétrique** — aucun claim (« terminé », « fonctionne », « vert ») sans citation déterministe : sortie de commande, SHA, artefact CI, capture sim. PR ouverte ≠ livré ; tests verts ≠ feature qui marche. Cela vaut pour Claude, pour Codex et pour tout agent.
- **mint-lead** — borne le périmètre, refuse la dérive, décide merge/no-merge sur preuves, et **porte le battement produit** : à lui de faire finir chaque batch sur du touchable, pas seulement sur du propre.
- **mint-quality-gate** — gates auth/privacy/onboarding/runtime, pouvoir de veto ; vérifie le diff et les preuves, pas les résumés.
- **mint-mobile / mint-backend / mint-swiss-brain** — implémentation par verticale, chacun dans ses paths owned.
- **mint-experience** — journey, architecture d'information, microcopy pédagogique, accessibilité, tests de compréhension ; cinquième lentille des panels design, avec un mandat de cohérence envers le design validé qui ne prime jamais sur l'accessibilité ni sur les résultats de compréhension mesurés (périmètre détaillé : `.claude/agents/mint-experience.md`).
- **mint-integrations-security** — consentement, provenance, API externes futures, conception de la sécurité, chemins de récupération (périmètre détaillé : `.claude/agents/mint-integrations-security.md`).
- **Codex en critique croisée, bornée dans le temps** — tout livrable significatif (diff, ADR, constat, synthèse) passe une critique Codex couvrant six axes : code, architecture, flow, UX, actuariat, légal. Ne jamais laisser le même agent construire, s'auto-noter et promouvoir.
- **Preuves en CI, liées au SHA** — l'exécuteur des preuves est la CI, pas la machine de l'agent qui a écrit le code. Les gates locaux (lefthook) restent des filtres rapides ; ils ne promeuvent rien.
- **Julien** — valide la compréhension et la douceur en 3-5 minutes par micro-batch ; arbitre les compromis majeurs.

## Ce qui est déjà prouvé et se réutilise

Deux noms fixent le vocabulaire partagé de la reconstruction (adoptés le 2026-08-03). **Orientation Strangler Fig** = la structure visée : MINT Next pousse à côté du produit vivant (`product/mint_next/`, surface `hidden_design_lab_only`), verticale par verticale, couture explicite — contrat de navigation, discriminateur de payloads L1/L2-L4, gates de promotion par batch (cf. D-11). Tant qu'aucune verticale promue n'intercepte une route du legacy, c'est un chantier parallèle scellé ; il ne devient strangler qu'à la première interception mesurable, et le retrait du legacy se mesure route par route. **Legacy-as-library** = politique interne MINT (métaphore, pas un pattern homologué) : l'ancien MINT est une carrière de matériaux dont on n'extrait que des blocs prouvés — critères d'extraction : tests verts liés au bloc, reçus/provenance, référence de PR mergée — jamais du legacy en vrac. Pendant que le figuier pousse, l'ancien arbre reste vivant et soigné : les P0 du produit courant se corrigent sur le legacy sans attendre la reconstruction.

L'inventaire se fait contre dev actuel (règle 9). Ces briques sont mergées sur dev et se réutilisent telles quelles :

- **Receipts = provenance** — `MoneyTruthReceipt` scelle chaque chiffre affiché avec son calcul d'origine : contrat v1 (#1107), consommation mobile avec bande d'incertitude et « pourquoi ce chiffre » (#1108), handoff vers le coach (#1109), grounding du prompt coach (#1116, #1118), harnais de parité coach×receipt (#1114), boucle de preuve documentée (#1121), propagation retraite et rente/capital (#1171).
- **Étalon fiscal ESTV** — une seule source de taux, calibrée ESTV, tous les services drainés vers elle : taux marginal unique (#1061) + lint interdisant toute nouvelle table par canton (#1062) ; drains successifs (#1063, #1064, #1072, #1076, #1136) ; capital v2 130 points officiels (#990), capital marié 26 cantons (#1097), nœuds bas 15k/25k/35k (#1099), oracle d'interpolation 260 vecteurs (#1098) ; gains immobiliers (#1090), succession/donation sourcé (#1086, #1087) ; miroirs invalidité (#1170) et dividende/bénéfice (#1167).
- **Citation gate du coach** — le coach ne produit pas de chiffre sans invocation d'outil et citation : gate + registry (#564), entrées tool_call_id (#616), grammaire du narrateur (#617, #634, #637) ; code sous `services/backend/app/services/coach/` (`citation_registry.py`, `citation_grammar.py`, `runtime_freshness_gate.py`).
- **Confidence + historisation** — le score de confiance 4 axes est historisé (#1168) et la courbe de lucidité est visible dans « Ton histoire » (#1169) ; bande D10 `MintTrameConfiance` (#1163, #1164). C'est le socle de « l'évolution visible » (D5).
- **Tier B flows** — 18 life events couverts par des flows Maestro seedés avec assertions chiffrées : cadrage (#1132), lots B1→B5 (#1134, #1137, #1139, #1141, #1142, #1143), seeds dédiés (#1133, #1135, #1138). C'est l'ossature du walkthrough en CI.
- **Chantiers North Star D1-D5 amorcés** — mode local invité (#1160), portes qui disent vrai + coach guidé (#1161), historisation et courbe D5 (#1168, #1169).

## Counter-arguments and data gaps

- **What does the strongest opposing view say ?**
  La rigueur maximale du handoff (roasts systématiques repartant de zéro, invalidation totale au moindre finding, gardes d'acceptation durcies) a réellement trouvé des bugs que des relectures expertes avaient manqués — le bypass `sitecustomize` en est la preuve documentée (handoff §34-35). Relâcher cette pression (roast scoped au fix, plafond méta 20 %) pourrait laisser passer le prochain bypass. Symétriquement, le gate « runtime touchable à chaque batch » peut pousser à des démos superficielles : un écran qui se tape au doigt n'est pas une preuve de justesse actuarielle, et la pression du touchable peut éroder la discipline RED-first qu'elle est censée compléter.
- **What does this source not address ?**
  Le plafond méta 20 % n'a pas de méthode de mesure définie (20 % de quoi — commits, lignes, temps ?) ; il sera apprécié au jugé du lead tant qu'aucune métrique n'est fixée. La critique croisée Codex sur six axes n'a pas de rubrique versionnée par axe (l'actuariat et le légal sont appréciés par le même agent que le code). L'audit Fable du 2026-08-03 est une session, pas un artefact versionné : ce document est son seul enregistrement durable. Enfin, la fusion fil rouge × North Star n'a été validée par aucun test utilisateur — le recouvrement « à 80 % » est un jugement éditorial, pas une mesure. Le pattern Strangler Fig porte aussi son risque classique, non traité ici : la double maintenance (legacy + MINT Next) qui s'éternise si les promotions de verticales ne suivent pas le rythme des batches.
- **What would change this conclusion ?**
  Un bypass de preuve passant la CI (l'exécuteur neutre compromis) → retour à l'invalidation large de §29 et re-litigation de la règle 7. Deux batches consécutifs dont le runtime touchable se révèle être une démo sans justesse (finding actuariel post-merge) → renforcer l'étape F au détriment du battement. Une situation où le plafond méta 20 % bloquerait un durcissement de sécurité réellement nécessaire → exception explicite par décision versionnée, pas par dérive silencieuse.

## Sources

- `/Users/julienbattaglia/Desktop/MINT-HANDOFF-2026-08-03.md` — §3 (fil rouge), §13 (workflow A→I), §15 (définition de « terminé »), §29 (anti-dérive), §34-35 (bugs trouvés par les audits).
- `.planning/decisions/2026-07-31-north-star-experience.md` — North Star en une phrase, 12 principes sourcés, chantiers D1-D5.
- Audit Fable/Opus 5 du handoff, session du 2026-08-03 — cinq amendements repris dans « Doctrine anti-dérive v2 » ; ce document en est l'enregistrement canonique.
- PRs citées : #564, #616, #617, #634, #637, #990, #1061, #1062, #1063, #1064, #1072, #1076, #1086, #1087, #1090, #1097, #1098, #1099, #1105, #1107, #1108, #1109, #1114, #1116, #1118, #1121, #1132, #1133, #1134, #1135, #1136, #1137, #1138, #1139, #1140, #1141, #1142, #1143, #1160, #1161, #1163, #1164, #1167, #1168, #1169, #1170, #1171 (repo MINT-IA/MINT).

## Status & follow-up

- Statut : **Proposed** — passe Decided après critique croisée Codex et lecture de Julien.
- Implementation tracking : chaque prochain batch référence ce document et déclare son gate « runtime touchable » dans sa PR.
- Re-litigation triggers : listés dans « What would change this conclusion ? » ci-dessus.
