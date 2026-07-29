---
description: Constat §3.4 du hand-off 2026-07-27 — TAUX_PLUS_VALUE_IMMOBILIERE de housing_sale_service (6/26, aucune source) est prouvée fausse sur ZH — la table affiche 0 % après 20 ans de détention alors que le mécanisme zurichois réel est un rabais MAXIMAL de 50 % sur un tarif progressif par montant du gain, jamais zéro. Le zéro de GE après 25 ans est, lui, exact — la table mélange vrai et faux sans source. Décision 🔴.
---

# Constat — housing_sale : un zéro inventé sur l'impôt du gain immobilier ZH

Ligne §3.4 du hand-off `2026-07-27-HANDOFF.md` :
`housing_sale_service.py:52`, couverture 6/26, source déclarée : aucune.
Phase 1 (« prouver »).

## 1. Qui appelle, et ce qui atteint l'écran

`TAUX_PLUS_VALUE_IMMOBILIERE` (`:52`, 6 cantons, paliers dégressifs par
**durée de détention** ; défaut `TAUX_PLUS_VALUE_DEFAULT` pour 20
cantons) est lue à `:274` (`_get_tax_rate`) → `_compute_impot_plus_value`
= `plus-value × taux` — l'impôt sur le gain immobilier **affiché** lors
d'une simulation de vente. Surface : `endpoints/life_events.py`
(`HousingSaleService`) → `housing_sale_screen.dart`. C'est une surface à
gros montants : quelques points d'écart se chiffrent en dizaines de
milliers de francs.

## 2. Écart prouvé — ZH

La table : `ZH: … (20, 999, 0.0)` — **zéro impôt après 20 ans de
détention**.

La réalité zurichoise (ZKB, sources spécialisées concordantes) : la
Grundstückgewinnsteuer est un **tarif progressif par montant du gain**,
auquel s'appliquent des majorations pour détention courte et un rabais de
5 % dès la 5ᵉ année puis 3 % par an, **plafonné à 50 % dès 20 ans** —
l'impôt n'atteint **jamais zéro**. Pour un gain de 500'000 CHF détenu 25
ans, la table affiche 0 CHF là où Zurich prélève environ la moitié du
tarif plein — un zéro inventé, la variante la plus grave de la règle 5 du
hand-off (« borner une valeur hors plage fabrique un chiffre »).

Le mécanisme lui-même est mal modélisé : le taux réel dépend d'abord du
**montant du gain** (progressif), la durée n'étant qu'un modificateur
(majoration < 2 ans, rabais ≥ 5 ans). Une table `durée → taux plat` ne
peut pas représenter ça, quel que soit son calibrage.

## 3. Le piège : la table mélange vrai et faux

Le zéro de **GE après 25 ans est exact** (LCP genevoise : 0 % au-delà de
25 ans de détention). Une vérification par sondage qui tomberait sur GE
conclurait « la table est bonne ». C'est le cas d'école du hand-off §2 :
sans source par ligne, chaque cellule doit être prouvée individuellement
— 6 cantons × ~6 paliers + le défaut, personne ne l'a fait.

## 4. Verdict — décision 🔴

Même triptyque que succession/donation : plages ou mécanisme réel sourcé
par canton (majoration/rabais + renvoi au calculateur cantonal),
recalibrage complet, ou statu quo étiqueté. Spécificité ici : le
mécanisme réel (progressif par gain × modificateur de durée) est
**modélisable** proprement pour ZH au moins — les barèmes sont publics et
stables ; c'est un candidat à un modèle calibré plutôt qu'à une plage.
La suppression sèche viderait `housing_sale_screen` (« produit vide »).

## 5. Limites

- ZH prouvé (sources spécialisées concordantes, dont ZKB) ; GE confirmé
  sur le seul point du zéro à 25 ans ; BE/VD/LU/BS et le défaut n'ont pas
  été comparés ligne à ligne.
- Le rendu exact de `housing_sale_screen.dart` n'a pas été retracé widget
  par widget.

Sources : [ZKB — Grundstückgewinnsteuer](https://www.zkb.ch/de/blog/meine-vorsorge/grundstueckgewinnsteuer.html) · [neho — Grundstückgewinnsteuer Zürich](https://neho.ch/de/blog/grundstuckgewinnsteuer-zurich) · [Stadt Zürich — Grundstückgewinnsteuer](https://www.stadt-zuerich.ch/de/lebenslagen/steuern/grundstueckgewinnsteuer.html)
