---
description: Sources primaires archivées des barèmes de l'impôt sur les gains immobiliers ZH/VD/GE (ADR 2026-07-28 P5) — tarif ZH § 225 StG par montant de gain, barème VD art. 72 LI par durée avec double comptage d'occupation, barème GE art. 84 LCP révisé 1.1.2025 (2 % dès 25 ans). L'extraction JSON retranscrit ces textes champ par champ ; la table fabriquée TAUX_PLUS_VALUE_IMMOBILIERE est fausse sur les trois cantons.
---

# Gains immobiliers — sources primaires 2026 (ZH, VD, GE)

## TLDR

Phase données de l'unité P5 de l'ADR
[2026-07-28-remplacements-succession-donation-immo-lamal](../../../decisions/2026-07-28-remplacements-succession-donation-immo-lamal.md) :
trois sources primaires téléchargées le 2026-07-28 et archivées ici, retranscrites
dans `extraction.json`. La phase code remplacera
`housing_sale_service.py::TAUX_PLUS_VALUE_IMMOBILIERE` (fabriquée, fausse sur
ZH, VD et GE — écarts détaillés dans `extraction.json.ecarts_vs_table_fabriquee`)
par des modèles calibrés générés depuis cette archive, avec tests de parité
archive ↔ py ↔ dart et rejeu des vecteurs officiels ZH.

## Fichiers

| Fichier | Source | Contenu |
|---|---|---|
| `zstb-225-1-zh-tarif.pdf` | Steueramt Kanton Zürich (zh.ch, StA eForm 225.1 / 09.25) | Tarif § 225 StG : 7 tranches par gain 10→40 %, majorations +50 %/<1 an et +25 %/<2 ans, rabais 5 % à 5 ans pleins +3 %/an plafonné 50 %, franchise 5'000 CHF ; tableau B = vecteurs officiels |
| `li-vd-642-11-consolide.pdf` | lexfind.ch tolv/200645 (LI RSV 642.11 consolidée) | Art. 72 (pages 36-38) : barème dégressif 25 lignes 30→7 %, al. 4 double comptage des années d'occupation prouvées ; art. 74 partage 5/12 commune |
| `lcp-ge-d3-05-consolide.html` | silgeneve.ch (LCP rsGE D 3 05, état 1.1.2026, Windows-1252) | Art. 84 : 50/40/30/20/15/10 % puis 2 % dès 25 ans (modif. 257, en vigueur 1.1.2025) ; art. 85 remploi = remboursement |
| `extraction.json` | ce dossier | Retranscription champ par champ + `meta.methode` + vecteurs officiels ZH + écarts vs table fabriquée |

## Hors périmètre de cette collecte

BE, LU, BS et le défaut « autres cantons » : l'ADR (item 7) les traite en
mécanisme sourcé + renvoi au calculateur cantonal officiel, sans table — leurs
quotités communales et tarifs liés au revenu les rendent non-tabulables. À
sourcer dans la phase code ; aucune valeur chiffrée ne doit être inventée pour
eux d'ici là.
