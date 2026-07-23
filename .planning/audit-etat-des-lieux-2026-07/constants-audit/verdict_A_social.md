# Verdict Groupe A — Assurances sociales (AVS / AI / APG / AC)

> Audit factuel (bead MINT_nosync-zaw). Exigence : « rien d'inventé ne guide l'utilisateur ».
> Chaque verdict CONFIRMÉE repose sur une source officielle **consultée** (pas de mémoire).
> Fichier audité : `.planning/audit-etat-des-lieux-2026-07/constants-audit/group_A_social.json` (43 clés)
> + 5 constantes hors-registre de `apps/mobile/lib/constants/social_insurance.dart`.
> Date de vérification : 2026-07-23.

## Source pivot (autorité maximale)

**OFAS/BSV — « Montants valables à partir du 1er janvier 2026 »** (daté 06.11.2025) :
<https://www.bsv.admin.ch/dam/fr/sd-web/sAgdISSXenMT/f_Betr%C3%A4ge%202026.pdf>
Mention explicite : *« Introduction de la 13e rente de vieillesse dans l'AVS — Aucune modification des montants par rapport au 1er janvier 2025. »*
=> Les montants 2026 = montants 2025 (prochaine indexation prévue 2027).

Autres sources officielles consultées :
- Échelle 44 officielle (valable dès 1.1.2025, doc 318.117.1) : <https://sozialversicherungen.admin.ch/fr/d/6850/download>
- Mémento 3.04 « Flexibilisation de la retraite » (anticipation + ajournement) : <https://www.ahv-iv.ch/p/3.04.f>
- Mémento 2.03 « Cotisations des personnes sans activité lucrative » : <https://www.ahv-iv.ch/p/2.03.f>
- 13e rente (premier versement déc. 2026) : <https://www.eak.admin.ch/fr/premier-versement-13e-rente-avs>
- LACI art. 27 (durée max indemnités) : <https://juriup.ch/outils/indemnites-chomage/> ; Directive LACI IC (SECO) : <https://www.arbeit.swiss/dam/secoalv/fr/dokumente/publikationen/kreisschreiben/kreisschreiben2/Directive%20LACI%20IC.pdf.download.pdf/Directive%20LACI%20IC.pdf>
- OACI art. 33 (seuil 80 %/70 %) : <https://juriup.ch/outils/indemnites-chomage/>

## Compte par verdict

| Verdict | Nombre |
|---|---|
| CONFIRMÉE | 35 |
| PÉRIMÉE | 8 |
| DOUTEUSE | 5 |
| INTROUVABLE | 0 |
| **Total** | **48** (43 registre + 5 hors-registre) |

---

## Tableau complet (format strict)

| clé | valeur MINT | VERDICT | valeur officielle 2026 | source URL exacte | validité |
|---|---|---|---|---|---|
| avs.max_monthly_pension | 2520 | CONFIRMÉE | 2 520 fr. | https://www.bsv.admin.ch/dam/fr/sd-web/sAgdISSXenMT/f_Betr%C3%A4ge%202026.pdf | 2025-2026 |
| avs.min_monthly_pension | 1260 | CONFIRMÉE | 1 260 fr. | https://www.bsv.admin.ch/dam/fr/sd-web/sAgdISSXenMT/f_Betr%C3%A4ge%202026.pdf | 2025-2026 |
| avs.couple_max_monthly | 3780 | CONFIRMÉE | 3 780 fr. (plafonnement 150 %) | https://www.bsv.admin.ch/dam/fr/sd-web/sAgdISSXenMT/f_Betr%C3%A4ge%202026.pdf | 2025-2026 |
| avs.echelle44 | table 14700→1260 … 88200→2520 (pas 2940, 26 lignes) | PÉRIMÉE | Échelle 44 officielle : bornes RAMD 15 120→1 260 … 90 720→2 520 (pas 1 512, 51 lignes). Ex. RAMD 52 920 = 2 016 (MINT : 1 914) | https://sozialversicherungen.admin.ch/fr/d/6850/download | 2025-2026 |
| avs.max_annual_pension | 30240 | CONFIRMÉE | 30 240 fr. (= 2 520 × 12). NB : effectif 13 rentes dès 2026 = 32 760 fr. | https://www.bsv.admin.ch/dam/fr/sd-web/sAgdISSXenMT/f_Betr%C3%A4ge%202026.pdf | 2025-2026 (base 12 mois) |
| avs.contribution_rate_employee | 0.053 | DOUTEUSE | 5,3 % = taux combiné AVS+AI+APG part salarié (AVS seule = 4,35 %). Nom « avs » trompeur + double-comptage possible avec ai/apg séparés | https://www.bsv.admin.ch/fr/cotisations-apercu | 2025-2026 |
| avs.contribution_rate_total | 0.106 | DOUTEUSE | 10,6 % = taux combiné AVS+AI+APG total (AVS seule = 8,7 %). Idem : mal nommé, risque de double-comptage | https://www.bsv.admin.ch/fr/cotisations-apercu | 2025-2026 |
| avs.full_contribution_years | 44 | CONFIRMÉE | 44 ans (échelle 44, LAVS art. 29bis/ter) | https://sozialversicherungen.admin.ch/fr/d/6850/download | permanent |
| avs.reference_age_men | 65 | CONFIRMÉE | 65 ans | https://www.ahv-iv.ch/p/3.04.f | permanent |
| avs.reference_age_women | 64.5 | DOUTEUSE | Transitoire : née 1961→64+3m (2025), 1962→64+6m (2026), 1963→64+9m (2027), 1964+→65 (dès 2028). « 64.5 » ne colle qu'à la cohorte 2026 ; incohérent avec le code Dart (par année de naissance, cible 65) | https://www.ahv-iv.ch/p/3.04.f | cohorte 2026 seulement |
| avs.anticipation_reduction | 0.068 | CONFIRMÉE | 6,8 %/an (1 an = 6,8 %, 2 ans = 13,6 %). NB : taux spéciaux avantageux pour femmes nées 1961-1969 dès 1.1.2025 | https://www.ahv-iv.ch/p/3.04.f | 2025-2026 |
| avs.deferral_supplement.1 | 0.052 | CONFIRMÉE | 5,2 % (ajournement 1 an) | https://www.ahv-iv.ch/p/3.04.f | permanent (actuariel) |
| avs.deferral_supplement.2 | 0.106 | PÉRIMÉE | **10,8 %** (ajournement 2 ans) — MINT sous-évalue | https://www.ahv-iv.ch/p/3.04.f | permanent (actuariel) |
| avs.deferral_supplement.3 | 0.164 | PÉRIMÉE | **17,1 %** (ajournement 3 ans) — mémento cite explicitement « durée d'ajournement de trois ans = 17,1 % » | https://www.ahv-iv.ch/p/3.04.f | permanent (actuariel) |
| avs.deferral_supplement.4 | 0.227 | PÉRIMÉE | **24,0 %** (ajournement 4 ans) — MINT sous-évalue | https://www.ahv-iv.ch/p/3.04.f | permanent (actuariel) |
| avs.deferral_supplement.5 | 0.315 | CONFIRMÉE | 31,5 % (ajournement 5 ans) | https://www.ahv-iv.ch/p/3.04.f | permanent (actuariel) |
| avs.retiree_franchise_monthly | 1400 | CONFIRMÉE | 1 400 fr./mois (franchise rentiers actifs). NB : base = RAVS art. 6quater, pas « LAVS art. 4 » | https://www.ahv-iv.ch/p/2.03.f | 2025-2026 |
| avs.retiree_franchise_annual | 16800 | CONFIRMÉE | 16 800 fr./an (= 1 400 × 12) | https://www.ahv-iv.ch/p/2.03.f | 2025-2026 |
| avs.survivor_factor | 0.8 | CONFIRMÉE | 80 % de la rente de vieillesse (rente veuve/veuf, LAVS art. 36) = 1 008 à 2 016 fr. | https://www.ahv-iv.ch/fr/Assurances-sociales/Glossaire/term/witwen-und-witwerrente | 2025-2026 |
| avs.ramd_min | 14700 | PÉRIMÉE | **15 120 fr.** (RAMD plancher pour rente min = 12 × 1 260) | https://sozialversicherungen.admin.ch/fr/d/6850/download | 2025-2026 |
| avs.ramd_max | 88200 | PÉRIMÉE | **90 720 fr.** (RAMD plafond pour rente max = 6 × 15 120) | https://sozialversicherungen.admin.ch/fr/d/6850/download | 2025-2026 |
| avs.13th_pension_active | 1 (true) | CONFIRMÉE | Active — premier versement décembre 2026 | https://www.eak.admin.ch/fr/premier-versement-13e-rente-avs | dès 12.2026 |
| avs.13th_pension_start_year | 2026 | CONFIRMÉE | 2026 (premier versement déc. 2026) | https://www.eak.admin.ch/fr/premier-versement-13e-rente-avs | dès 12.2026 |
| avs.13th_pension_factor | 1.0833 (13/12) | CONFIRMÉE | +8,33 % (13e = 1/12 de la somme annuelle des rentes ; = 13/12 pour année pleine) | https://www.bsv.admin.ch/dam/fr/sd-web/sAgdISSXenMT/f_Betr%C3%A4ge%202026.pdf | dès 12.2026 |
| avs.voluntary_contribution_min | 514 | PÉRIMÉE | Mal libellé + périmé. Cotisation min. AVS/AI facultative (Suisses étranger) 2026 = **1 010 fr.** ; cotisation min. AVS/AI/APG non-actifs 2026 = **530 fr.** (514 = valeur 2023/2024) | https://www.bsv.admin.ch/dam/fr/sd-web/sAgdISSXenMT/f_Betr%C3%A4ge%202026.pdf | 2025-2026 |
| avs.voluntary_contribution_max | 25700 | PÉRIMÉE | **26 500 fr.** (cotisation max. personnes sans activité = 50 × 530). 25 700 = ancienne valeur (50 × 514) | https://www.ahv-iv.ch/p/2.03.f | 2025-2026 |
| avs.min_contribution_independent | 530 | CONFIRMÉE | 530 fr./an (cotisation min. AVS/AI/APG) | https://www.bsv.admin.ch/dam/fr/sd-web/sAgdISSXenMT/f_Betr%C3%A4ge%202026.pdf | 2025-2026 |
| avs.independent_min_income_threshold | 10100 | CONFIRMÉE | 10 100 fr. (limite inférieure barème dégressif). NB : limite supérieure = 60 500 fr. (absente du registre) | https://www.bsv.admin.ch/dam/fr/sd-web/sAgdISSXenMT/f_Betr%C3%A4ge%202026.pdf | 2025-2026 |
| ai.contribution_rate_employee | 0.007 | CONFIRMÉE | 0,7 % (AI part salarié) | https://www.bsv.admin.ch/fr/cotisations-apercu | 2025-2026 |
| ai.contribution_rate_total | 0.014 | CONFIRMÉE | 1,4 % (AI total) | https://www.bsv.admin.ch/fr/cotisations-apercu | 2025-2026 |
| ai.full_pension_monthly | 2520 | CONFIRMÉE | 2 520 fr. (rente AI max = rente AVS max) | https://www.bsv.admin.ch/dam/fr/sd-web/sAgdISSXenMT/f_Betr%C3%A4ge%202026.pdf | 2025-2026 |
| apg.contribution_rate_employee | 0.0025 | CONFIRMÉE | 0,25 % (APG part salarié) | https://www.bsv.admin.ch/fr/cotisations-apercu | 2025-2026 |
| apg.contribution_rate_total | 0.005 | CONFIRMÉE | 0,5 % (APG total) | https://www.bsv.admin.ch/fr/cotisations-apercu | 2025-2026 |
| apg.maternity_days | 98 | CONFIRMÉE | 98 jours = 14 semaines (LAPG art. 16d) | https://www.bsv.admin.ch/dam/fr/sd-web/sAgdISSXenMT/f_Betr%C3%A4ge%202026.pdf | permanent |
| apg.maternity_rate | 0.8 | CONFIRMÉE | 80 % du revenu (LAPG art. 16e) | https://www.bsv.admin.ch/fr/cotisations-apercu | permanent |
| apg.paternity_days | 10 | CONFIRMÉE | 10 jours = 2 semaines (congé de l'autre parent, LAPG art. 16i-16j) | https://www.bsv.admin.ch/fr/cotisations-apercu | permanent |
| ac.max_insured_salary | 148200 | CONFIRMÉE | 148 200 fr./an (12 350 fr./mois ; LACI art. 23 / OLAA art. 22, inchangé 2026) | https://www.guidesocial.ch/recherche/fiche/generatepdf/46 | 2016-2026 |
| ac.contribution_rate_employee | 0.011 | CONFIRMÉE | 1,1 % (part salarié, jusqu'au plafond) | https://www.bsv.admin.ch/fr/cotisations-apercu | 2025-2026 |
| ac.contribution_rate_total | 0.022 | CONFIRMÉE | 2,2 % (total, jusqu'au plafond) | https://www.bsv.admin.ch/fr/cotisations-apercu | 2025-2026 |
| ac.solidarity_rate_employee | 0.005 | CONFIRMÉE | 0,5 % (solidarité au-dessus du plafond, part salarié) | https://www.bsv.admin.ch/fr/cotisations-apercu | 2025-2026 |
| ac.solidarity_rate_total | 0.01 | CONFIRMÉE | 1,0 % (solidarité total) | https://www.bsv.admin.ch/fr/cotisations-apercu | 2025-2026 |
| ac.benefit_rate_standard | 0.7 | CONFIRMÉE | 70 % du gain assuré (LACI art. 22 al. 2) | https://juriup.ch/outils/indemnites-chomage/ | 2025-2026 |
| ac.benefit_rate_family | 0.8 | CONFIRMÉE | 80 % du gain assuré (LACI art. 22 al. 1) | https://juriup.ch/outils/indemnites-chomage/ | 2025-2026 |
| acSeuilSalaireMajore (Dart) | 3797 /mois | CONFIRMÉE | 3 797 fr./mois : seuil sous lequel le taux 80 % s'applique (OACI art. 33). NB sémantique : le 80 % s'applique AUSSI avec enfant OU invalidité ≥ 40 %, indépendamment du salaire | https://juriup.ch/outils/indemnites-chomage/ | 2025-2026 |
| acJoursMinCotisation (Dart) | 200 | DOUTEUSE | Valeur réelle mais sémantique fausse. 200 jours = assurés < 25 ans SANS obligation d'entretien (LACI art. 27 al. 4), PAS « < 22 mois de cotisation ». 12 mois de cotisation donnent 260 jours | https://juriup.ch/outils/indemnites-chomage/ | 2025-2026 |
| acJoursIntermediaireCotisation (Dart) | 260 | DOUTEUSE | Valeur réelle mais sémantique fausse. 260 jours = **12 mois** de cotisation (LACI art. 27 al. 2 let. a), PAS « 18-21 mois ». 18 mois donnent 400 jours | https://juriup.ch/outils/indemnites-chomage/ | 2025-2026 |
| acJoursSenior (Dart) | 520 | CONFIRMÉE | 520 jours = 22 mois de cotisation ET (âge ≥ 55 OU invalidité ≥ 40 %) (LACI art. 27 al. 2 let. c) | https://juriup.ch/outils/indemnites-chomage/ | 2025-2026 |
| acAgeSeuillSenior (Dart) | 55 | CONFIRMÉE | 55 ans (seuil pour 520 jours, LACI art. 27 al. 2 let. c) | https://juriup.ch/outils/indemnites-chomage/ | permanent |

---

## PÉRIMÉES (8) — correction proposée

1. **avs.echelle44** (table entière) — bornes RAMD (14 700 / 88 200) sont les valeurs 2023/2024, mais mappées aux rentes 2025 (1 260 / 2 520) : table interne incohérente. Ex. RAMD 52 920 → MINT 1 914 vs officiel **2 016** (écart 102 fr./mois). **Correction** : remplacer par l'échelle 44 officielle 2025/2026 (RAMD 15 120→1 260 … 90 720→2 520, pas de 1 512, 51 lignes) — doc OFAS 318.117.1.

2. **avs.ramd_min = 14700** → **15 120 fr.** (2025/2026).

3. **avs.ramd_max = 88200** → **90 720 fr.** (2025/2026).

4. **avs.deferral_supplement.2 = 0.106** → **0.108** (10,8 %).

5. **avs.deferral_supplement.3 = 0.164** → **0.171** (17,1 %) — confirmé par citation directe du mémento 3.04.

6. **avs.deferral_supplement.4 = 0.227** → **0.240** (24,0 %).

7. **avs.voluntary_contribution_min = 514** → clarifier la sémantique puis corriger : non-actifs 2026 = **530 fr.** ; AVS/AI facultative (Suisses de l'étranger) 2026 = **1 010 fr.**. (514 = valeur 2023/2024.)

8. **avs.voluntary_contribution_max = 25700** → **26 500 fr.** (cotisation max. personnes sans activité 2026 = 50 × 530).

## DOUTEUSES (5) — sémantique à corriger (valeur juste, nom/usage trompeur)

1. **avs.contribution_rate_employee = 0.053** et **avs.contribution_rate_total = 0.106** — valeurs correctes MAIS ce sont les taux **combinés AVS+AI+APG** (AVS seule = 4,35 % / 8,7 %). Le registre les nomme « avs » avec source « LAVS art. 5 » ET expose séparément ai (0,7/1,4) et apg (0,25/0,5). Un consommateur qui additionne avs+ai+apg double-compte (10,6 + 1,4 + 0,5 = 12,5 %, faux). **Correction** : renommer en `social.contribution_rate_avs_ai_apg_*` OU documenter « rate combiné, ne pas additionner avec ai/apg ». (Le fichier Dart le documente déjà lignes 367-372 ; le registre JSON non.)

2. **avs.reference_age_women = 64.5** — l'âge de référence femmes est **transitoire** par année de naissance (64+3m/64+6m/64+9m/65 pour 1961/1962/1963/1964+). « 64.5 » ne vaut que pour la cohorte 2026 (née 1962) et devient faux dès 2027. Incohérent avec le code Dart (`avsAgeReferenceFemme = 65` + fonction par année de naissance). **Correction** : ne pas stocker un scalaire ; modéliser par année de naissance (comme le Dart) avec cible 65 dès 2028, ou ajouter valid_from/valid_until par cohorte.

3. **acJoursMinCotisation = 200** — la valeur 200 existe dans la LACI mais correspond aux assurés **< 25 ans sans enfants** (art. 27 al. 4), pas à « < 22 mois de cotisation ». **Correction** : renommer `acJoursMax_moins25SansEnfant` et corriger le doc-comment.

4. **acJoursIntermediaireCotisation = 260** — 260 jours = **12 mois** de cotisation (art. 27 al. 2 let. a), pas « 18-21 mois ». **Correction** : mapper 12 mois → 260, 18 mois → 400. Le bloc doc Dart (lignes 331-344) est incorrect de bout en bout et doit être réécrit : `acJoursStandard = 400` est aussi mal libellé (« ≥ 22 mois, âge < 55 » alors que 400 = 18 mois de cotisation).

## Note sur la modélisation 13e rente AVS (exigence spécifique)

Cohérente : `avs.13th_pension_active = true`, `start_year = 2026`, `factor = 13/12 ≈ 1.0833`, et le Dart calcule `avsMaxAnnualRenteForYear(year)` = 30 240 (≤ 2025) / 32 760 (≥ 2026). Conforme à la règle OFAS (13e = 1/12 de la somme annuelle des rentes de vieillesse effectivement versées, +8,33 %, uniquement rentes de vieillesse — pas AI, survivants, enfants). Premier versement décembre 2026. Aucune correction requise.
