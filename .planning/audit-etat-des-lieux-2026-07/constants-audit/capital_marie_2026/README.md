# Recalibrage capital MARIÉ — collecte étalon ESTV (2026-07-28)

**TLDR.** L'impôt cantonal+communal sur une prestation en capital de prévoyance,
état civil MARIÉ, a été collecté auprès de l'API officielle ESTV
(`API_calculateManyCapitalTaxes`, `Relationship=2`) pour les 26 chefs-lieux sur
la MÊME grille que la table célibataire `CANTONAL_CAPITAL_TAX_CHF`
(5 montants : 100k / 250k / 500k / 750k / 1M CHF). Ces valeurs remplacent le
rabais forfaitaire inventé `MARRIED_CAPITAL_TAX_DISCOUNT_BY_CANTON`
(8 cantons tabulés + `FALLBACK = 0.82` pour les 18 autres). La table générée
est `CANTONAL_CAPITAL_TAX_MARRIED_CHF` (étalon, interpolée comme la
célibataire). Le rabais forfaitaire s'écartait de la réalité ESTV de
**-0.277 à +0.270** (médiane +0.124)
sur le seul point 250k.

## Provenance

- **Source** : simulateur fiscal officiel ESTV (`swisstaxcalculator.estv.admin.ch`),
  opération `API_calculateManyCapitalTaxes` (endpoint
  `POST /delegate/ost-integration/v1/lg-proxy/operation/c3b67379_ESTV/API_calculateManyCapitalTaxes`).
- **Date de collecte** : 2026-07-28.
- **Profil** : marié (`Relationship=2`), sans enfant, sans confession
  (`Confession1=4`, `Confession2=0`), homme (`Gender=1`), âge au versement 65,
  commune = chef-lieu. Identique au profil célibataire à l'état civil près.
- **TaxLocationID** : repris à l'identique de la collecte célibataire
  (`../capital_tax_2026/lotA.json` + `lotB.json`).
- **Année fiscale** : 2026 (SG/TI servis 2026 par l'ESTV comme pour le célibataire).

## Méthode de vérification (pourquoi ces valeurs font foi)

Le **même pipeline** a re-capturé le CÉLIBATAIRE (`Relationship=1`) et reproduit
**exactement** les 130 points de `CANTONAL_CAPITAL_TAX_CHF` déjà committée
(0 écart sur `cantonal_communal` ET sur l'IFD). Reproduire l'étalon célibataire
au CHF près prouve que le pipeline est identique à la collecte d'origine ; la
collecte mariée (même pipeline, `Relationship=2`) est donc aussi autoritaire.

## Écart du rabais forfaitaire vs réalité ESTV (par canton)

`eff = impôt_cantonal_marié_ESTV / impôt_cantonal_célibataire_ESTV`. Le ratio
n'est PAS constant selon le montant — c'est un effet de barème (splitting), pas
un coefficient plat : d'où l'échec structurel du rabais forfaitaire.

| Canton | ancien rabais | eff ESTV (min … max) | eff médian | Δ(eff−rabais) @250k |
|---|---|---|---|---|
| AG | 0.82 (fallback) | 0.687 … 0.945 | 0.904 | +0.024 |
| AI | 0.82 (fallback) | 0.800 … 1.000 | 1.000 | +0.135 |
| AR | 0.82 (fallback) | 0.750 … 0.750 | 0.750 | -0.070 |
| BE | 0.80 (tabulé) | 0.840 … 0.928 | 0.909 | +0.109 |
| BL | 0.82 (fallback) | 1.000 … 1.000 | 1.000 | +0.180 |
| BS | 0.82 (fallback) | 1.000 … 1.000 | 1.000 | +0.180 |
| FR | 0.82 (fallback) | 0.867 … 0.989 | 0.975 | +0.113 |
| GE | 0.73 (tabulé) | 0.659 … 0.914 | 0.878 | +0.101 |
| GL | 0.82 (fallback) | 1.000 … 1.000 | 1.000 | +0.180 |
| GR | 0.82 (fallback) | 0.750 … 1.000 | 1.000 | +0.180 |
| JU | 0.82 (fallback) | 0.770 … 0.831 | 0.776 | -0.030 |
| LU | 0.82 (tabulé) | 1.000 … 1.000 | 1.000 | +0.180 |
| NE | 0.82 (fallback) | 0.890 … 0.986 | 0.982 | +0.070 |
| NW | 0.82 (fallback) | 0.817 … 1.000 | 1.000 | +0.137 |
| OW | 0.82 (fallback) | 1.000 … 1.000 | 1.000 | +0.180 |
| SG | 0.82 (fallback) | 0.909 … 0.909 | 0.909 | +0.089 |
| SH | 0.82 (fallback) | 0.712 … 1.000 | 1.000 | +0.060 |
| SO | 0.82 (fallback) | 0.767 … 1.000 | 0.980 | +0.067 |
| SZ | 0.82 (fallback) | 0.543 … 1.000 | 0.795 | -0.277 |
| TG | 0.82 (fallback) | 0.833 … 0.833 | 0.833 | +0.013 |
| TI | 0.80 (tabulé) | 0.667 … 1.000 | 0.933 | +0.200 |
| UR | 0.82 (fallback) | 1.000 … 1.000 | 1.000 | +0.180 |
| VD | 0.78 (tabulé) | 0.810 … 0.944 | 0.881 | +0.064 |
| VS | 0.81 (tabulé) | 0.980 … 0.980 | 0.980 | +0.170 |
| ZG | 0.70 (tabulé) | 0.709 … 0.986 | 0.969 | +0.190 |
| ZH | 0.73 (tabulé) | 0.610 … 1.000 | 0.871 | +0.270 |

Faits saillants :
- **ZH** : rabais 0.73 supposé constant ; réalité ESTV = 1.000 à ≤250k, mais
  descend à 0.61 à 750k (splitting réservé aux hauts montants).
- **SZ** : forte réduction à bas montant (0.543 à 250k), nulle à haut montant.
- Cantons **sans** réduction mariée cantonale (eff = 1.000 partout) : BL, BS, GL, LU, OW, UR.
- **SO** : l'ESTV arrondit le marié +1 CHF au-dessus du célibataire à 750k/1M
  (pas de réduction ; artefact d'arrondi ESTV — l'invariant `marié ≤ célibataire`
  tient à ±1 CHF).

## IFD marié (hors périmètre de ce recalibrage — à documenter pour suite)

L'IFD (art. 38 LIFD = 1/5 du barème revenu) diffère aussi selon l'état civil
(barème marié art. 36 al. 2, splitting) : 363 / 3676 / 10176 / 16676 / 23000 CHF
(marié) contre 537 / 3901 / 10501 / 17101 / 23000 CHF (célibataire) aux 5 points.
Ce recalibrage NE traite QUE la part cantonale (périmètre décidé : « même format
que la table célibataire, interpolation comme le célibataire au lieu du rabais »).
L'étalon `estimate_capital_withdrawal_tax` conserve l'IFD célibataire
(`FEDERAL_BRACKETS`, art. 36 al. 1) pour le marié — approximation PRÉ-EXISTANTE
inchangée (l'ancien modèle faisait déjà ainsi). Les valeurs IFD mariées sont
archivées dans `consolidated.json` (`ifd_marie_par_montant`) pour un éventuel
PR fédéral dédié.

## Fichiers

- `consolidated.json` — table mariée (`points_chf_marie`), IFD marié/célibataire,
  référence célibataire, `meta.methode`.
- `raw_married.json` — réponses brutes ESTV (requête + réponse) par point marié.
