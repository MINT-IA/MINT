---
date: 2026-08-08
status: Decided
authors: Julien Battaglia + Codex
description: MINT est un compagnon suisse de lucidité financière à vie, fondé sur un jumeau financier canonique et des mini-plans adaptatifs.
related:
  - .planning/decisions/2026-08-03-doctrine-reconstruction-mint.md
  - .planning/decisions/2026-05-17-data-architecture-event-log-vs-bitemporal.md
  - docs/data-flow.md
---

# Jumeau financier à vie et mini-plans adaptatifs

## Décision produit

> **MINT est le compagnon de lucidité financière des personnes vivant en
> Suisse. Il apprend progressivement leur situation, maintient cette
> connaissance dans le temps et la transforme en explications, simulations,
> arbitrages et petites actions suivies.**

MINT n'est ni un catalogue d'écrans, ni un chatbot qui improvise, ni un dossier
rempli une fois. Sa boucle canonique est :

`question ou événement → faits connus → manque minimal → consentement → fait
canonique → calcul déterministe → explication/widget → action → suivi`.

Le Coach est une interface de collecte, de recherche et d'explication. Il n'est
ni la base de données ni le moteur de calcul. Aujourd'hui, Ma situation, Coach
et Explorer sont différentes vues d'une même vérité utilisateur.

## Contrat du jumeau financier

Un fait financier exact est structuré. Il ne vit pas uniquement dans un prompt,
un transcript, un document, un RAG ou l'état d'un widget. Il porte au minimum :

- un identifiant sémantique stable et une valeur typée avec unité ;
- la personne et, si nécessaire, la période fiscale concernées ;
- la source, la date d'assertion, la fraîcheur et la version du schéma ;
- son statut : déclaré, extrait, dérivé, estimé ou inconnu ;
- la preuve de consentement applicable ;
- une histoire de correction sans réétiquetage silencieux.

Tout chemin qui collecte un fait doit prouver avant promotion :

1. sauvegarde par l'unique chemin canonique ;
2. rechargement après relance ;
3. visibilité compréhensible dans « Ma situation » ;
4. correction et suppression par l'utilisateur ;
5. au moins un consommateur réel hors de l'écran de collecte ;
6. invalidation des résultats dépendants après correction ;
7. absence de transmission distante sans contrat et consentement correspondants.

Un écran qui ne satisfait pas ce cycle est un prototype non promouvable, même
s'il est visuellement terminé et testé en isolation.

## Contrat des mini-plans

La lucidité doit pouvoir devenir un mini-plan choisi par l'utilisateur : réserve
d'urgence, désendettement, achat immobilier, optimisation fiscale, prévoyance ou
autre événement de vie.

Un plan contient un objectif, un état initial scellé, un horizon, une trajectoire
calculée, une prochaine action réversible et un état `sur_la_trajectoire`,
`a_ajuster`, `bloque` ou `donnees_insuffisantes`. Il référence les faits et la
version des règles qui l'ont produit. Un changement de vie déclenche une
proposition de recalcul ; MINT ne modifie jamais silencieusement l'engagement de
l'utilisateur. Le suivi peut être recalculé souvent, mais ne sollicite
l'utilisateur que lorsqu'il dispose d'un pouvoir d'agir.

Les mini-plans sont une capacité fondamentale du produit, mais leur premier
runtime vient après le cycle complet des faits. Ordre de construction :

1. jumeau financier canonique ;
2. faits visibles, corrigeables et historisés ;
3. calculs et arbitrages déterministes ;
4. un mini-plan vertical ;
5. suivi adaptatif ;
6. connexions banques, assurances, prévoyance et administrations.

## Premier Lego de correction

Avant toute nouvelle question logement, le parcours existant doit faire passer
ses faits de l'état éphémère au cycle canonique : statut d'occupation, présence
d'une hypothèque, disponibilité et année de l'attestation, intérêts annuels et
solde hypothécaire. Le stockage local canonique existant est réutilisé ; aucun
repository logement parallèle n'est créé. La synchronisation distante reste
hors périmètre tant que son contrat de consentement n'est pas accepté.

## Counter-arguments and data gaps

Le contre-argument le plus fort est qu'un simple dossier financier et des
simulateurs thématiques pourraient offrir la majorité de la valeur avec moins
de complexité qu'un jumeau longitudinal. Cette décision ne prétend pas encore
prouver que les utilisateurs comprendront « Ma situation », qu'ils accepteront
la collecte progressive, ni que le stockage canonique actuel couvrira les
futures résolutions de conflits avec les sources externes.

La décision doit être réexaminée si :

- Une preuve démontre que le stockage canonique actuel ne peut pas assurer
  atomiquement sauvegarde, correction et suppression.
- La connexion à une source externe exige une résolution de conflits qui ne
  peut pas être représentée par l'historique prévu.
- Des tests utilisateurs montrent que « Ma situation » n'est pas comprise comme
  la mémoire contrôlable de MINT.
