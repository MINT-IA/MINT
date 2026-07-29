# Verdict B — Prévoyance (LPP + pilier 3a) — 28 paramètres

Audit factuel vs sources officielles (OFAS/BSV, LPP, OPP3, OEPL), vérifié via WebSearch le 2026-07-23.
Fichier audité : `group_B_prevoyance.json` (reviewed_at 2026-06-26).

Format : `clé | valeur MINT | VERDICT | valeur officielle 2026 | source | validité`

## Pilier 3a — courant

| clé | valeur MINT | VERDICT | valeur off. 2026 | source | validité |
|---|---|---|---|---|---|
| pillar3a.max_with_lpp | 7258 CHF | CONFIRMÉE | 7258 CHF | OPP3 art. 7 al. 1 ; OFAS/mon3p/postfinance 2026 | 2026 = 2025 (inchangé, CF n'a pas ajusté OPP3) |
| pillar3a.max_without_lpp | 36288 CHF | CONFIRMÉE | 36288 CHF (20% du revenu, plafond) | OPP3 art. 7 al. 2 ; mon3p/compassurance 2026 | plafond atteint dès 181'440 CHF revenu net |
| pillar3a.income_rate_without_lpp | 0.2 (20%) | CONFIRMÉE | 20% | OPP3 art. 7 al. 2 | inchangé |

## Pilier 3a — limites historiques (max avec LPP)

Table de référence officielle (révision biennale par le Conseil fédéral) :
2015-2018 = 6768 · 2019-2020 = 6826 · 2021-2022 = 6883 · 2023-2024 = 7056 · 2025-2026 = 7258.
Source croisée : finpension (table historique), Canton de Berne (2023=7056), Credit Suisse (2023=7056), Descartes.

| clé | valeur MINT | VERDICT | valeur off. | source | validité |
|---|---|---|---|---|---|
| historical_limits.2026 | 7258 | CONFIRMÉE | 7258 | finpension / OFAS | OK |
| historical_limits.2025 | 7258 | CONFIRMÉE | 7258 | finpension / OFAS | OK |
| historical_limits.2024 | 7056 | CONFIRMÉE | 7056 | finpension / VZ | OK |
| historical_limits.2023 | 6883 | **PÉRIMÉE** | **7056** | Canton BE + Credit Suisse (2022-11) : plafond relevé à 7056 en 2023 | ERREUR : corriger 6883 → 7056 |
| historical_limits.2022 | 6826 | **PÉRIMÉE** | **6883** | Canton BE (2022 = 6883) ; finpension | ERREUR : corriger 6826 → 6883 |
| historical_limits.2021 | 6826 | **PÉRIMÉE** | **6883** | finpension (2021-2022 = 6883) | ERREUR : corriger 6826 → 6883 |
| historical_limits.2020 | 6826 | CONFIRMÉE | 6826 | finpension | OK |
| historical_limits.2019 | 6826 | CONFIRMÉE | 6826 | finpension | OK |
| historical_limits.2018 | 6826 | **PÉRIMÉE** | **6768** | finpension (2015-2018 = 6768) | ERREUR : corriger 6826 → 6768 |
| historical_limits.2017 | 6768 | CONFIRMÉE | 6768 | finpension | OK |
| historical_limits.2016 | 6768 | CONFIRMÉE | 6768 | finpension | OK |

Nota : les transitions historiques dans le fichier MINT sont décalées d'un cran (mauvaises années de bascule). 4 valeurs fausses (2018, 2021, 2022, 2023). 2020/2019/2017/2016/2024+ corrects.

## LPP — seuils (2026, = 2025, ré-confirmé PR #967, non re-litigé)

| clé | valeur MINT | VERDICT | valeur off. 2026 | source | validité |
|---|---|---|---|---|---|
| lpp.entry_threshold | 22680 CHF | CONFIRMÉE | 22680 CHF | LPP art. 7 ; info-lpp.ch 2026 | 2026 = 2025 |
| lpp.coordination_deduction | 26460 CHF | CONFIRMÉE | 26460 CHF | LPP art. 8 ; info-lpp.ch 2026 | 2026 = 2025 |
| lpp.min_coordinated_salary | 3780 CHF | CONFIRMÉE | 3780 CHF | LPP art. 8 al. 2 ; info-lpp.ch 2026 | 2026 = 2025 |
| lpp.max_coordinated_salary | 64260 CHF | CONFIRMÉE | 64260 CHF | LPP art. 8 al. 1 ; info-lpp.ch (90720-26460) | 2026 = 2025 |
| lpp.max_insured_salary | 90720 CHF | CONFIRMÉE | 90720 CHF | LPP art. 8 al. 1 ; info-lpp.ch 2026 | 2026 = 2025 |

## LPP — taux

| clé | valeur MINT | VERDICT | valeur off. 2026 | source | validité |
|---|---|---|---|---|---|
| lpp.conversion_rate | 0.068 (6.8%) | CONFIRMÉE | 6.8% | LPP art. 14 al. 2 ; info-lpp.ch | inchangé depuis 2014 ; réforme LPP 21 rejetée → reste 6.8% |
| lpp.min_interest_rate | 1.25% | CONFIRMÉE | 1.25% | OPP2 ; admin.ch (décision CF 05.11.2025 : maintien 1,25% pour 2026) | 2026 = 2025 |
| lpp.conversion_rate_complementaire | 0.058 (5.8%) | **DOUTEUSE** | pas de valeur légale — fixé librement par chaque caisse (surobligatoire/enveloppant), fourchette ~4.8%-6% en 2026 | Zurich/UBS/Swiss-Serenity 2026 : taux surobligatoire non fixé par loi | hypothèse MINT, PAS une loi. 5.8% = haut de fourchette (beaucoup de caisses déjà à 5.0-5.4%). source_url OFAS ne contient AUCUN 5.8% → citation trompeuse. À traiter comme hypothèse éditable, jamais comme constante légale |

## LPP — bonifications de vieillesse (art. 16, % du salaire coordonné)

| clé | valeur MINT | VERDICT | valeur off. | source | validité |
|---|---|---|---|---|---|
| lpp.bonification.25_34 | 0.07 (7%) | CONFIRMÉE | 7% | LPP art. 16 ; info-lpp.ch 2026 | OK |
| lpp.bonification.35_44 | 0.10 (10%) | CONFIRMÉE | 10% | LPP art. 16 ; info-lpp.ch 2026 | OK |
| lpp.bonification.45_54 | 0.15 (15%) | CONFIRMÉE | 15% | LPP art. 16 ; info-lpp.ch 2026 | OK |
| lpp.bonification.55_65 | 0.18 (18%) | CONFIRMÉE | 18% | LPP art. 16 ; info-lpp.ch 2026 | OK (55 ans → âge de référence) |

## LPP — EPL / rachats

| clé | valeur MINT | VERDICT | valeur off. | source | validité |
|---|---|---|---|---|---|
| lpp.epl_minimum | 20000 CHF | CONFIRMÉE | 20000 CHF | OEPL art. 5 al. 1 (versement anticipé min) ; aeis.ch/Raiffeisen | valeur OK ; source_title MINT « OPP2 art. 5 » imprécis — la base légale exacte est l'OEPL (Ordonnance sur l'EPL) art. 5, pas OPP2 |
| lpp.epl_buyback_lock_years | 3 ans | CONFIRMÉE | 3 ans | LPP art. 79b al. 3 ; e-Potek/CPV | délai de blocage 3 ans post-rachat avant retrait capital/EPL ; déductibilité annulée si non respecté |

---

## Synthèse

- **Total : 28 paramètres**
- **CONFIRMÉE : 23**
- **PÉRIMÉE : 4** (limites historiques 3a 2018, 2021, 2022, 2023)
- **DOUTEUSE : 1** (taux conversion surobligatoire 5.8%)
- **INTROUVABLE : 0**

### PÉRIMÉES (corrections)
1. `pillar3a.historical_limits.2023` : 6883 → **7056**
2. `pillar3a.historical_limits.2022` : 6826 → **6883**
3. `pillar3a.historical_limits.2021` : 6826 → **6883**
4. `pillar3a.historical_limits.2018` : 6826 → **6768**
(Cause : années de bascule décalées. Table correcte : 2015-2018=6768, 2019-2020=6826, 2021-2022=6883, 2023-2024=7056, 2025-2026=7258.)

### DOUTEUSE
1. `lpp.conversion_rate_complementaire` (5.8%) : n'est PAS une valeur légale. Le taux surobligatoire/enveloppant est fixé par chaque caisse (fourchette ~4.8%-6% en 2026, tendance baissière). Le `source_url` OFAS ne contient aucun 5.8%. À exposer comme hypothèse éditable, jamais comme constante réglementaire. Correction : soit reclasser en paramètre d'hypothèse (non-« source_title » légal), soit retirer.
