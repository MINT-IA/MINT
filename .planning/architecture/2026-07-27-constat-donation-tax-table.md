---
description: Constat §3.4 du hand-off 2026-07-27 — TAUX_DONATION_CANTONAL de donation_service (8/26, source « Lois cantonales » sans document) est la jumelle structurelle de la table succession (#1078) — mêmes taux plats par lien de parenté, même défaut silencieux (18 cantons). VD prouvé faux : la table affiche descendant 0.0 alors que Vaud impose la ligne directe (seuil 2025 : 300'000 CHF/enfant/an). Décision 🔴 commune avec la succession.
---

# Constat — donation_service : la jumelle donation de la table succession

Ligne §3.4 du hand-off `2026-07-27-HANDOFF.md` : `donation_service.py:56`,
couverture 8/26, source déclarée « Lois cantonales sur l'impot sur les
donations » — une catégorie, pas un document. Phase 1 (« prouver »).

## 1. Qui appelle, et ce qui atteint l'écran

`TAUX_DONATION_CANTONAL` (`:56`, 8 cantons × 6 liens de parenté, taux
plats) est lue à `:232` (`_get_tax_rate`) puis `_compute_tax` (`:235`) =
`montant × taux` — l'impôt de donation **affiché**. Surface :
`endpoints/life_events.py` (`DonationService` instancié `:67`) →
`donation_screen.dart`. Les **18 cantons absents** reçoivent
`TAUX_DONATION_DEFAULT` (`:92`) en silence, et un lien de parenté inconnu
retombe sur le taux « tiers » (`:233`).

## 2. Écart contre sources primaires

**VD (dans la table)** : `descendant: 0.0`. Réalité (vd.ch, LMSD) :
Vaud est l'un des **rares cantons qui imposent la ligne directe
descendante**, en donation comme en succession. Depuis le 1.1.2025 :
franchise de **300'000 CHF par enfant et par année civile** en donation
(1'000'000 CHF par ligne en succession) — au-delà, barème cantonal
progressif plus **impôt communal jusqu'à 100 % du cantonal**. Le 0.0
plat de la table n'est vrai que sous le seuil ; il rate la franchise, la
progressivité et le communal — trois mécanismes qu'un taux plat ne peut
pas porter.

**Structure** : la table est la **jumelle** de `CANTON_SUCCESSION_TAX`
(constat #1078) — mêmes catégories, même modèle plat, mêmes cantons
manquants fabriqués par défaut. En droit cantonal, l'impôt sur les
donations suit très généralement les barèmes successoraux — les écarts
prouvés sur GE (centimes additionnels +110 %, jusqu'à ~54 % pour les
tiers) et NW (franchise + exonération concubin, #1058) se transfèrent.

## 3. Verdict — même décision 🔴 que la succession, à trancher ensemble

Les deux tables (succession #1078, donation) portent la même classe
d'erreur, alimentent des surfaces sœurs (`life_events`), et appellent la
même décision : plages sourcées directionnelles (recommandé), recalibrage
complet, ou statu quo étiqueté. Les trancher séparément produirait deux
conventions divergentes sur des écrans jumeaux.

## 4. Limites

- Ancrage primaire sur VD (vd.ch/LMSD) ; GE et NW transférés des constats
  #1078/#1058, pas re-vérifiés spécifiquement pour la donation.
- Le rendu widget par widget de `donation_screen.dart` n'a pas été
  retracé.

Sources : [vd.ch — successions / donations](https://www.vd.ch/etat-droit-finances/impots/impots-pour-les-individus/les-impots-les-differents-types-dimpots/successions-/-donations) · [RSM — modifications législatives VD](https://www.rsm.global/switzerland/fr/news/donations-et-successions-dans-le-canton-de-vaud-modifications-legislatives-importantes) · [Delen — seuils 2025](https://www.delen.ch/fr-ch/blog/modification-des-seuils-dimposition-impot-sur-les-successions-et-sur-les-donations-dans-le-canton-de-vaud)
