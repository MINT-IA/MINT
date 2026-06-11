---
phase: mint-illogism-fixes
plan: 02
subsystem: financial_core
tags: [lpp, rente, conversion-rate, financial_core, parity, strangler-fig, l1-canonical, d4]

# Dependency graph
requires:
  - phase: mint-illogism-fixes-01
    provides: "LppCalculator.accumulateAvoir + financial_parity_test.dart (harnais W1)"
provides:
  - "LppCalculator.monthlyRenteFromAvoir — source canonique unique pour la conversion avoir stocké -> rente mensuelle (taux de caisse + réduction retraite anticipée LPP art. 13 al. 2)"
  - "6 sites de rente/impact délégués au canonique (mariage, response_card, financial_summary, independants, cap_sequence x2, job_comparison x2)"
  - "financial_parity_test.dart — groupe « Parity W2 — Rente LPP » (6 cas)"
affects: [mint-illogism-fixes-03, mint-illogism-fixes-04, mint-illogism-fixes-05]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Strangler-fig (D-11) : les sites de rente deviennent des façades déléguant à LppCalculator.monthlyRenteFromAvoir"
    - "UNE base de taux par cas : adjustedConversionRate (réduction anticipée) en amont de toute conversion avoir -> rente"

key-files:
  created: []
  modified:
    - apps/mobile/lib/services/financial_core/lpp_calculator.dart
    - apps/mobile/lib/screens/mariage_screen.dart
    - apps/mobile/lib/services/response_card_service.dart
    - apps/mobile/lib/screens/profile/financial_summary_screen.dart
    - apps/mobile/lib/services/independants_service.dart
    - apps/mobile/lib/services/minimal_profile_service.dart
    - apps/mobile/lib/services/cap_sequence_engine.dart
    - apps/mobile/lib/services/job_comparison_service.dart
    - apps/mobile/test/services/financial_parity_test.dart

key-decisions:
  - "Nouveau helper canonique monthlyRenteFromAvoir (avoir stocké -> rente mensuelle) plutôt que d'appeler adjustedConversionRate inline partout — un seul point d'entrée, signature explicite (baseRate + retirementAge), réduction anticipée appliquée systématiquement"
  - "Base de taux unifiée par profil : tous les sites avec un profil utilisent profile.prevoyance.tauxConversion (défaut 6.8% min légal, ou taux de caisse déclaré) — élimine le mélange 0.068 / 0.058 source du spread cross-écrans"
  - "minimal_profile_service NON re-câblé sur monthlyRenteFromAvoir : il PROJETTE l'avoir jusqu'à la retraite (projectToRetirement, déjà canonique via adjustedConversionRate:118) — opération distincte de la conversion d'avoir stocké. Seul le littéral 0.058 a été remplacé par la constante nommée (unification de branche)"
  - "job_comparison renteAnnuelle + axe 4 (rente projetée) : même cause racine (taux ad-hoc) re-câblée sur le canonique bien que :209 n'était pas listé explicitement dans le plan — Rule 1, même fichier Task 2"

patterns-established:
  - "monthlyRenteFromAvoir({avoir, baseRate, retirementAge, referenceAge}) : retourne avoir × adjustedConversionRate / 12, 0 pour avoir non-positif"
  - "groupe « Parity W2 — Rente LPP » : helper unit + minimal_profile (projection) + cap_sequence (conversion stockée + impact rachat)"

requirements-completed:
  - MATRIX-salarie_swiss-4
  - MATRIX-independent_no_lpp-5
  - MATRIX-expat_us-4
  - MATRIX-frontalier-3
  - MATRIX-cadre_divorce_hypo-3
  - MATRIX-couple_acheteurs-3
  - MATRIX-returning_swiss_gaps-5
  - MATRIX-D4

# Metrics
duration: 16min
completed: 2026-06-11
---

# Phase mint-illogism-fixes Plan 02 (W1) : Rente LPP — conversion canonique — Summary

**UNE source canonique (`LppCalculator.monthlyRenteFromAvoir`, financial_core L1) pour convertir un avoir LPP stocké en rente mensuelle — un seul taux de conversion par cas (taux de caisse + réduction retraite anticipée LPP art. 13 al. 2), éliminant le spread device-prouvé 250-347 CHF/mois (D4 : 0.068 ET 0.058 rendus dans la même session) et la divergence d'impact rachat 283 vs 242 CHF/mois.**

## Performance

- **Duration:** 16 min
- **Started:** 2026-06-11T11:33:53Z
- **Completed:** 2026-06-11T11:50:02Z
- **Tasks:** 2 / 2
- **Files modified:** 9 (8 code + 1 deferred-items.md)

## Accomplishments

### Task 1 (RED) — groupe de parité « Rente LPP »
- Commit : `09a8958da` — `test(mint-illogism-fixes-02): add failing parity tests for rente LPP`
- Ajout du groupe « Parity W2 — Rente LPP » à `financial_parity_test.dart` (6 cas).
- **RED prouvé** : compile-failure `Member not found: 'LppCalculator.monthlyRenteFromAvoir'` (sortie quotée ci-dessous), helper introduit au GREEN.

```
test/services/financial_parity_test.dart:259:39: Error: Member not found: 'LppCalculator.monthlyRenteFromAvoir'.
00:00 +0 -1: Some tests failed.
```

### Task 1 (GREEN) — helper canonique + re-câblage des sites de rente
- Commit : `0376224bf` — `feat(mint-illogism-fixes-02): unify rente LPP on LppCalculator canonical`
- **`LppCalculator.monthlyRenteFromAvoir`** (nouvelle fonction pure) : `avoir × adjustedConversionRate(baseRate, retirementAge) / 12`, 0 pour avoir non-positif. `baseRate` défaut = 6.8% min légal (LPP art. 14 al. 2) ; `retirementAge` défaut = âge de référence (65, pas de réduction).
- **mariage_screen:94** : façade déléguant au canonique. Supprime `0.068` hardcodé ; utilise `profile.prevoyance.tauxConversion` + `profile.effectiveRetirementAge`.
- **response_card_service:776** : façade déléguant au canonique. Supprime l'usage direct de `lppTauxConversionSurobligDecimal` ET le commentaire périmé « conservative 5.4% » de la ligne :779.
- **financial_summary_screen:127** : façade déléguant au canonique. Supprime `prev.tauxConversion / 12` inline.
- **independants_service:599** : rente annuelle via `LppCalculator.adjustedConversionRate(baseRate: _tauxConversion, retirementAge: 65)` (indépendants visent l'âge de référence). Supprime le multiply ad-hoc.
- **minimal_profile_service:108-115** : branche unifiée sur constantes nommées (`lppTauxConversionSurobligDecimal` / `lppTauxConversionMinDecimal` via registry) au lieu du littéral `0.058`. Le chemin de conversion reste `projectToRetirement` (déjà canonique).

### Task 2 (GREEN) — base unique pour l'impact rachat + rente job-comparison
- Commit : `dd839b6db` — `feat(mint-illogism-fixes-02): unify rachat/job-rente impact on canonical base`
- **cap_sequence_engine._estimateLppMonthly (:622)** + **_estimateRachatImpact (:639)** : rente et impact mensuel d'un rachat via `monthlyRenteFromAvoir` (même base que la rente — fin de la divergence 283 vs 242 CHF/mois pour 50000 de rachat). `rachatMaximum` (capacité) reste inchangé — seul l'IMPACT mensuel est re-câblé.
- **job_comparison_service.renteAnnuelle (:75)** : taux surobligatoire routé par `adjustedConversionRate(baseRate: rate/100, retirementAge: 65)` — au taux de référence, valeur préservée (test :141 `500000 × 5.2% = 26000` toujours vert).
- **job_comparison axe 4 rente projetée (:209)** : même cause racine (`tauxConversionSurobligatoire / 100 / 12` ad-hoc) re-câblée sur `monthlyRenteFromAvoir` — Rule 1, même fichier Task 2.
- 3 cas cap_sequence ajoutés au groupe « Rente LPP » (avoir 300000 délègue ; retraite anticipée 62 < 65 réduction ; rachat 50000 impact identique).

## Oracle matrice re-run (GREEN, 0-TRUST §9)

Commande : `cd apps/mobile && flutter test test/services/financial_parity_test.dart`
Sortie : `00:00 +10: All tests passed!` (10/10 — 4 cas W1 plan 01 + 6 cas W2 plan 02)

| Cas W2 | Résultat après fix |
|---|---|
| avoir 300000 — monthlyRenteFromAvoir | UNE rente == 1700.00 CHF/mois (300000 × 0.068 / 12) |
| retraite anticipée 62 < 65 (helper) | rente == 1550.00 CHF/mois (300000 × 0.062 / 12), strictement < 1700 |
| minimal_profile projection | retraite anticipée -> rente projetée strictement inférieure (réduction canonique appliquée) |
| cap_sequence avoir 300000 | délègue à monthlyRenteFromAvoir (== canonique au centime) |
| cap_sequence retraite anticipée 62 | rente < référence (réduction art.13 al.2 transite désormais par cap_sequence) |
| cap_sequence rachat 50000 | impact == 50000 × 0.068 / 12, identique à la rente (fin 283 vs 242) |

## Verification

| Gate | Commande | Résultat |
|---|---|---|
| Parité W1+W2 | `flutter test test/services/financial_parity_test.dart` | `+10: All tests passed!` |
| Régression services | `flutter test test/services/` | `+5828: All tests passed!` |
| Tests sites directs | `flutter test cap_sequence_engine_test job_comparison_service_test independants_service_test response_card_service_test response_card_service_fatca_test` | `+189: All tests passed!` |
| Screens + golden + journeys | `flutter test financial_summary_screen_test life_event_screens_v2_smoke_test job_comparison_profile_seed_test golden_couple_validation_test golden_couple_integrated_test test/journeys/` | `+334: All tests passed!` |
| Golden couple (exit code) | `flutter test test/golden/golden_couple_validation_test.dart` | `+18: All tests passed!` exit=0 |
| Analyse statique | `flutter analyze <9 fichiers touchés>` | `No issues found!` |
| Banned terms LSFin | scan diff `6c0e6008c..HEAD` (garanti/optimal/meilleur/sans risque/...) | 0 dans les additions |
| Accent FR | `accent_lint_fr.py --file <chaque fichier touché>` | 0 violation introduite (1 pré-existante hors-scope -> deferred) |

## Acceptance criteria

- AC1 (Task 1) : `grep "0\.068" mariage_screen independants_service` -> **0 résultat** hors commentaires.
- AC2 (Task 1) : `grep "adjustedConversionRate|monthlyRenteFromAvoir" <4 sites rente>` -> **4** (≥ 4).
- AC4 (Task 1) : `grep "5.4%|conservative" response_card_service` -> **0 résultat** (commentaire périmé :779 corrigé).
- AC (Task 2) : `grep "tauxConversion" cap_sequence_engine job_comparison_service` -> plus d'usage direct pour le calcul d'impact ; toutes occurrences restantes sont des `baseRate:` (délégation visible), des déclarations de champ, ou du texte d'alerte d'affichage.
- Parité `flutter test test/services/financial_parity_test.dart` exit 0.

## Design panel (4-lens) — mariage_screen + financial_summary_screen

Règle `feedback_design_panel_before_push` (aucune exception « petit fix »). Les changements sont des re-câblages de la SOURCE de données (valeur de pré-remplissage de la rente) — aucune modification du widget tree, de la copie i18n, ou de la surface a11y. Revue 4-lens appliquée inline (l'executor isolé ne peut pas spawn de subagents) :

- **UX** : aucun changement de layout/flow. La valeur de rente pré-remplie utilise désormais une base de conversion cohérente sur tous les écrans (même avoir -> même rente affichée). PASS.
- **a11y** : aucun nouveau widget, aucun label sémantique modifié, aucun changement contraste/touch-target. `MintAmountField` (mariage) et `HeroGapCard` (financial_summary) inchangés. PASS.
- **Adversarial** : avoir 0/null -> helper retourne 0 (champ `min: 0`, pas de crash) ; retraite anticipée -> taux réduit (valeur inférieure, toujours ≥ 0, dans la plage du slider) ; pas de NaN/Infinity (avoir fini, taux clampé [0.03, baseRate]). PASS.
- **Engineering/wiring** : délégation au canonique, imports ajoutés (`lpp_calculator.dart`), pas de dead code ; les consommateurs de `_renteLpp` (calcul survivant, slider, partner LPP) ne dépendent pas de la source de la valeur ; `flutter analyze` clean. PASS.

Verdict : 4/4 PASS, push autorisé.

## Requirements fermés (8)

salarie_swiss-4, independent_no_lpp-5, expat_us-4, frontalier-3, cadre_divorce_hypo-3, couple_acheteurs-3, returning_swiss_gaps-5, D4.

Note : `MATRIX-illogismes-2026-06-09.md` est read-only (contrat) — fermetures consignées ici uniquement.

## Deviations from Plan

- **[Rule 1 — Bug] job_comparison axe 4 (rente projetée :209) re-câblé sur le canonique**
  - **Found during:** Task 2 (grep d'acceptance `tauxConversion`)
  - **Issue:** `job_comparison_service.dart:209-216` calculait une 2e rente projetée avec `tauxConversionSurobligatoire / 100 / 12` ad-hoc — même cause racine que `renteAnnuelle:75`, non listée explicitement dans `<interfaces>`.
  - **Fix:** délégation à `LppCalculator.monthlyRenteFromAvoir` (retirementAge=65, valeur préservée).
  - **Files modified:** apps/mobile/lib/services/job_comparison_service.dart
  - **Commit:** dd839b6db

- **[Scope clarification — pas une déviation de comportement] minimal_profile_service garde projectToRetirement**
  - Le plan listait minimal_profile dans Task 1. Son chemin de rente est une PROJECTION jusqu'à la retraite (déjà canonique via `projectToRetirement` -> `adjustedConversionRate:118`), distincte de la conversion d'avoir STOCKÉ des écrans. Re-câbler sur `monthlyRenteFromAvoir` aurait changé la sémantique (un test l'a révélé : projection 2717 vs conversion stockée 1417). Seul le littéral `0.058` a été remplacé par la constante nommée (unification de branche demandée par le plan). Documenté pour traçabilité.

- **[Out-of-scope — deferred] accent FR pré-existant response_card_service:983**
  - `accent_lint_fr` signale `securite` -> `sécurité` ligne :983, introduit par commit `afc3e62d5` (hors du diff plan-02, qui touche ~772-784). Logué dans `deferred-items.md`, NON corrigé (SCOPE BOUNDARY + Karpathy #3).

## Known Stubs

Aucun. Tous les sites produisent des valeurs réelles câblées au canonique ; aucun placeholder / TODO / valeur vide introduit.

## Threat Flags

Aucune nouvelle surface de sécurité. Conforme au threat register du plan : T-ILF-02-01 (Tampering intégrité des sites de rente/rachat) et T-ILF-02-02 (Repudiation commentaire :779 trompeur) sont **mitigés** par la délégation `adjustedConversionRate` + la parité au centime (casse la CI à toute régression) + la correction du commentaire :779.

## Self-Check: PASSED

Tous les fichiers modifiés existent sur disque ; les trois commits de tâche (`09a8958da`, `0376224bf`, `dd839b6db`) sont présents dans `git log`.
