---
description: Audit factuel des variables métier 2026 (bead MINT_nosync-zaw) — 132 paramètres vérifiés contre sources officielles consultées le 2026-07-23, 12 valeurs corrigées (échelle 44 complète, bornes RAMD, historique 3a, barème IFD 2026), goldens recalculés, suivis ouverts.
---

# CONSTANTS-AUDIT — variables métier 2026 (bead MINT_nosync-zaw)

> Demande Julien (verbatim, 2026-07-22) : « il faut contrôler tous les textes, toutes les
> variables métiers 2026 […] être sceptique sur tout ce qui est métier et le revérifier sur
> le net pour figer vraiment les valeurs […] Il faut que tout soit factuel, vérifié, daté,
> dans nos bases de données. »

Date d'audit : 2026-07-23 · SHA de départ : `8d059e502` · Portée : registre réglementaire
(113 paramètres), fallbacks Dart, barèmes fiscaux hardcodés, hypothèses produit.

## Méthode

1. **Inventaire** — dump du `RegulatoryRegistry` (113 paramètres → `constants-audit/registry_dump.json`),
   découpage en 4 groupes : A social (43), B prévoyance (28), C fiscal (39), D LAMal + hypothèses (3 + hardcodés).
2. **Diff mécanique Lot 1** — registre ↔ fallbacks Dart (`constants-audit/lot1_diff.json`) :
   **0 divergence de valeur**, mais **9 clés absentes du registre** (voir suivis).
3. **Vérification en ligne** — 4 agents parallèles, obligation de consulter la source
   (WebSearch/WebFetch, aucune valeur « de mémoire »), verdicts par clé dans
   `constants-audit/verdict_{A_social,B_prevoyance,C_fiscal,D_hypotheses}.md`.
4. **Contre-vérification de première main** — le PDF officiel OFAS **318.117.011**
   (« Montants valables dès le 1.1.2025/2026 ») a été téléchargé et l'échelle 44 (p. 20)
   transcrite directement — pas de reprise d'un agrégateur.
5. **Correction + re-preuve** — valeurs corrigées dans le registre + fallbacks Dart + codegen,
   goldens recalculés à la main depuis la table officielle, suites complètes re-exécutées.

## Verdicts (132 paramètres vérifiés)

| Groupe | Vérifiés | Conformes | Périmés/incorrects | Douteux |
|---|---|---|---|---|
| A — AVS/AI/APG/AC | 48 | 35 | 8 | 5 |
| B — LPP + 3a | 28 | 22 | 4 | 2 |
| C — Fiscal | 39 + 2 blocs hardcodés | 5 | 1 bloc (barème IFD) | 34 + 1 bloc |
| D — LAMal + hypothèses | 3 + hardcodés | 3 | 0 | hypothèses → DÉFENDABLE sauf suivis |

Le grand nombre de « douteux » du groupe C est un défaut de **provenance** (valid_from/valid_until
vides, source_url générique), pas de valeur — traité comme suivi de fond, pas comme hot-patch.

## Corrections appliquées (mêmes commit — registre + Dart + goldens)

| # | Quoi | Avant | Après | Source consultée |
|---|---|---|---|---|
| 1 | Échelle 44 complète (51 lignes) | table approximative (pas 1512, valeurs interpolées) | table officielle p. 20 doc **318.117.011** | sozialversicherungen.admin.ch/fr/d/6850/download |
| 2 | `avs.ramd_min` / `avs.ramd_max` | 14 700 / 88 200 (bornes 2023) | **15 120 / 90 720** | idem (36× rente min annuelle) |
| 3 | Suppléments d'ajournement 2/3/4 ans | valeurs erronées | **10,8 % / 17,1 % / 24,0 %** | Mémento 3.04 |
| 4 | Cotisation AVS volontaire min/max | anciennes | **530 / 26 500** | Mémento 2.03 |
| 5 | Historique 3a (registre **et** `retroactive_3a_service.py`) | bascules décalées (2023=6883, 2021/22=6826, 2018=6826) | 2015-18 = 6768 · 2019-20 = 6826 · 2021-22 = 6883 · 2023-24 = **7056** · 2025-26 = 7258 | finpension / Canton BE / CS (croisées) |
| 6 | Barème IFD (`cantonal_comparator.py::FEDERAL_BRACKETS`) | barème pré-2024 | barème **2026** (progression à froid, 11 tranches, 15 200 → 794 000) | ESTV barème poste 2026 |
| 7 | Citations sources | LAMal art. 64 / LFLP vagues | **OAMal art. 103**, **OEPL art. 5**, doc 318.117.011 | fedlex |
| 8 | Description 5,8 % surobligatoire | présentée comme réglementaire | marquée hypothèse produit « aucune valeur légale » | — |
| 9 | `_REVIEWED` | 2026-06-26 | **2026-07-23** + bloc d'audit | — |

Codegen re-exécuté : `tools/codegen/regulatory_constants_to_dart.py --write`
(→ `regulatory_constants.g.dart`, hash `18ea16bb0ac9…`).

## Goldens recalculés (preuve que la correction traverse les moteurs)

Backend (`pytest tests/ -q` : **7965 passed, 0 failed**) :
- `test_minimal_profile.py::test_avs_ramd_lauren_67k_full_years` — 2156.6 → **2124.7**
  (interpolation linéaire bornes 15 120/90 720 ; l'écart vs table officielle ≈ 2218 documenté comme proxy prudent).
- `test_regulatory_registry.py::TestHistoricalLimits` — vert après correction des deux côtés (registre + service).
- `tests/fixtures/coach_tools_parity_v1.jsonl` — 3 fixtures recalculées à la main
  (julien 798.00, lauren 394.18, edge_age_65 2408.00 + composites) ; les 18 tests de parité passent
  avec tolérance serrée, ce qui valide l'arithmétique.

Mobile (6 fichiers de goldens AVS recalculés depuis la table officielle) :
- `renteFromRAMD(67000)` : ~2187 → **~2203.6** (entre 66 528 → 2197 et 68 040 → 2218)
- `renteFromRAMD(50000)` : ~1857.4 → **~1977.4** · `renteFromRAMD(48000)` → **~1950.7**
- Test de concavité recalculé (naïf 1865.5 vs table 1996.6)
- Entrées « RAMD max » 88 200 → 90 720 dans les tests d'intégration reg().
- Dédoublonnage `hallucination_detector.dart` (`avsRAMDMax` == `lppSalaireMax` = 90 720).

## Suivis ouverts (beads à créer — pas des hot-patchs)

1. **Provenance C** : 39 clés fiscales sans valid_from/valid_until ni source précise → campagne de sourcing.
2. **`EFFECTIVE_RATES_100K_SINGLE`** : contradiction sémantique (taux effectifs vs marginaux) + recalibrage 26 cantons.
3. **`capital_tax`** : modèle progressif par montant à remplacer (actuellement taux plat).
4. **AC durée-indemnités** : descriptions sémantiquement fausses (jours vs mois, seuils).
5. **`avs.reference_age_women`** : gérer par cohorte (transition AVS 21), pas une valeur unique.
6. **Nommage `avs.contribution_rate_*`** : les taux stockés sont AVS+AI+APG combinés — renommer ou documenter.
7. **9 clés absentes du registre** : `projection.{avs_indexation_rate,inflation_rate,life_expectancy,safe_withdrawal_rate}`,
   `ac.{enhanced_rate_threshold,intermediate_days,min_days,senior_age_threshold,senior_days}`.
8. **`rente_vs_capital_screen.dart:521`** : littéral lppReturn → `reg()`.

## Contre-arguments & lacunes de données

- **Interpolation linéaire vs paliers officiels** : les moteurs interpolent entre lignes de la
  table alors que l'officiel fonctionne par palier (« jusqu'à X → rente Y »). Écart max ≈ 21 CHF/mois,
  toujours conservateur (sous-estime). Choix documenté dans le code — pas corrigé car changer la
  sémantique de lookup est un choix produit (précision vs prudence) à trancher séparément.
- **Sources croisées ≠ source primaire** pour l'historique 3a : la table 2015-2026 est croisée sur
  3 sources concordantes (finpension, Canton de Berne, Credit Suisse), le RO année par année n'a pas
  été relu. Risque résiduel faible (3 sources indépendantes concordantes).
- **Les « douteux » C restent en production** : les 34 clés fiscales douteuses n'ont pas été gelées ;
  l'audit constate le défaut de provenance sans pouvoir affirmer que les valeurs sont fausses.
