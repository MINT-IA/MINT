---
description: Constat §3.1d du hand-off 2026-07-27 — _effectiveRates100kSingle de family_service.dart est le jumeau exact de la table backend drainée par #1064, alors que le canonique L1 (tax_calculator.dart estimateMarginalRate/estimateIncomeTaxV2) est DÉJÀ passé au modèle v2. Le drain touche l'écran mariage et exige de réconcilier le breakdown de déductions affiché avec le barème marié v2 — point produit à trancher avant code.
---

# Constat — family_service.dart : miroir périmé d'un canonique déjà drainé

Unité §3.1d du hand-off `2026-07-27-HANDOFF.md`. Question posée : « miroir
Dart ; établir d'abord le contrat de parité avec
`financial_core/tax_calculator.dart:342` ».

## 1. Le contrat de parité existe déjà — et family_service le viole

- `TaxCalculator.estimateMarginalRate` (`tax_calculator.dart:342`) est **déjà
  drainé** : pente locale du modèle v2 (`estimateIncomeTaxV2`, miroir du
  backend `couple_optimizer`, PR #1005), clamp [0.0, 0.50], plancher 5 %
  supprimé (commentaire Beads -8p4, `:355-359`). Le canonique L1 n'utilise
  plus de courbe « effectif 100k × facteur revenu × 1.3 ».
- `family_service.dart:202` porte `_effectiveRates100kSingle` — **jumeau à
  l'identique** (mêmes 26 valeurs, ZG 0.0823 → BS 0.1578) de la table backend
  `effective_rates_100k` drainée par la PR #1064, avec le même compagnon
  `_incomeAdjustment` (`:332-340`) et un fallback 0.13 pour canton inconnu
  (`:265`).

Le miroir a donc survécu à son original **des deux côtés** : côté backend
(#1064) et côté canonique mobile (PR #1005).

## 2. Un seul consommateur, mais c'est un écran

`compareFiscalMariage` (`:259-315`) est l'unique lecteur. Il alimente
`mariage_screen.dart` (grep `compareFiscalMariage` : screen + service + 2
fichiers de test). Modèle actuel :

- célibataires : `imposable × baseRate × _incomeAdjustment` (`:317-323`) ;
- mariés : mêmes ingrédients × **0.92** (« splitting-like effect », `:325-330`),
  après des déductions maison (`deductionMarie`, `deductionAssuranceMarie`,
  `deductionDoubleRevenu`, `deductionParEnfant`) retournées une à une dans la
  map (`:309-313`) — donc probablement affichées.

## 3. Pourquoi le drain n'est PAS mécanique

Remplacer la courbe par `estimateIncomeTaxV2(revenu, canton, isMarried: …)`
change le **modèle** de la comparaison mariage/célibat, pas seulement ses
chiffres :

1. le facteur 0.92 et le barème marié v2 représentent la même réalité
   (imposition commune) — les cumuler la compterait deux fois ;
2. les déductions maison sont en partie déjà incorporées dans le calibrage v2 —
   les soustraire de l'assiette **et** garder le breakdown affiché exige de
   décider ce que le breakdown raconte (pédagogie) vs ce qui entre dans le
   calcul (modèle) ;
3. le sens même du résultat (« pénalité de mariage : +X CHF ») peut basculer
   pour certains couples de revenus — c'est l'issue affichée de l'écran.

## 4. Les tests actuels ne verrouillent rien

`family_service_test.dart` n'assertit que des formes et des directions
(`greaterThan(0)`, `isA<double>`) — le signal « un test vert ne prouve pas un
fait du monde » (règle 3 du hand-off). Un drain qui inverserait la conclusion
pénalité/bonus passerait au vert sans bruit. La PR d'implémentation devra
apporter des assertions dérivées de l'étalon (parité Dart ↔ backend sur des
couples canton/revenus), pas des bandes écrites à la main.

## 5. Verdict

Le contrat de parité est établi : **la cible est `estimateIncomeTaxV2` /
`estimateMarginalRate` de `financial_core/tax_calculator.dart`, seule source
L1.** Mais l'unité d'implémentation n'est pas un drain mécanique : elle
emporte une micro-décision produit (que devient le breakdown de déductions
affiché, et le facteur 0.92) et touche un écran — donc panel design avant
push (règle dépôt) et preuve simulateur sur `mariage_screen`. Statut : reste
🟡 côté code ; prêt à passer en unité d'implémentation dès que la
micro-décision produit est actée (elle peut l'être dans la PR
d'implémentation elle-même si Julien la valide, ou via
`.planning/decisions/`).

## 6. Limites

- L'égalité « jumeau à l'identique » est vérifiée sur les 26 valeurs lues dans
  les deux fichiers ce jour, pas par un lint de parité automatique — c'est
  justement l'absence de ce lint qui a laissé le miroir survivre.
- L'impact chiffré du changement de modèle sur la pénalité affichée n'a pas
  été mesuré ici (nécessite d'exécuter les deux modèles Dart côte à côte) ;
  c'est le premier livrable de l'unité d'implémentation.
