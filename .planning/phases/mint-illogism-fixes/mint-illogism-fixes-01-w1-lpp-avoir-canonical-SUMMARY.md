---
phase: mint-illogism-fixes
plan: 01
subsystem: financial_core
tags: [lpp, financial_core, avoir, parity, strangler-fig, l1-canonical]

# Dependency graph
requires:
  - phase: mint-data-architecture-v1-01-calc-engine-canonical
    provides: "LppCalculator (financial_core L1) — projectToRetirement / computeSalaireCoordonne"
provides:
  - "LppCalculator.accumulateAvoir — source canonique unique pour l'estimation d'avoir LPP (balance-only)"
  - "coach_profile._estimateLppAvoir + minimal_profile_service._estimateLppBalance délèguent au canonique"
  - "financial_parity_test.dart — harnais de parité W1 (squelette des plans 02-05)"
affects: [mint-illogism-fixes-02, mint-illogism-fixes-03, mint-illogism-fixes-04, mint-illogism-fixes-05]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Strangler-fig (D-11) : estimateurs deviennent des façades déléguant au canonique L1"
    - "Test de parité par surfaces publiques uniquement (jamais via membres privés)"

key-files:
  created:
    - apps/mobile/test/services/financial_parity_test.dart
  modified:
    - apps/mobile/lib/services/financial_core/lpp_calculator.dart
    - apps/mobile/lib/models/coach_profile.dart
    - apps/mobile/lib/services/minimal_profile_service.dart

key-decisions:
  - "Ajout d'une fonction canonique balance-only accumulateAvoir plutôt que réutiliser projectToRetirement (qui retourne une rente, pas un avoir) — single source par layer sans changer la sémantique"
  - "monte_carlo_service NON modifié : déjà canonique (computeSalaireCoordonne + getLppBonificationRate registry) — Karpathy #3, ne pas toucher ce qui n'est pas cassé"

patterns-established:
  - "accumulateAvoir : miroir balance-only de projectToRetirement, startAge paramétrable (défaut 25, arrivalAge pour expats)"
  - "financial_parity_test.dart : harnais d'oracle matrice, groupes Avoir LPP / Rente / Remplacement / 3a / Invariants par plan"

requirements-completed:
  - MATRIX-salarie_swiss-1
  - MATRIX-independent_no_lpp-4
  - MATRIX-expat_us-3
  - MATRIX-frontalier-2
  - MATRIX-frontalier-5
  - MATRIX-cadre_divorce_hypo-2
  - MATRIX-couple_acheteurs-2
  - MATRIX-returning_swiss_gaps-3
  - MATRIX-returning_swiss_gaps-4

# Metrics
duration: 10min
completed: 2026-06-11
---

# Phase mint-illogism-fixes Plan 01 (W1) : Avoir LPP canonique — Summary

**UNE source canonique (`LppCalculator.accumulateAvoir`, financial_core L1) pour l'estimation d'avoir LPP par âge×salaire — élimine la classe DIVERGENT mesurée +15.4% (102k) à +105% (162k) entre coach_profile et minimal_profile_service.**

## Performance

- **Duration:** 10 min
- **Started:** 2026-06-11T11:17:36Z
- **Completed:** 2026-06-11T11:27:47Z
- **Tasks:** 2 / 2
- **Files modified:** 3 (+ 1 créé)

## Accomplishments

### Task 1 (RED) — squelette financial_parity_test.dart + groupe « Avoir LPP »
- Commit : `8a02e8470` — `test(mint-illogism-fixes-01): add failing parity tests for avoir LPP`
- Créé `apps/mobile/test/services/financial_parity_test.dart` (179 lignes, ≥4 cas du groupe « Parity W1 — Avoir LPP »).
- Tests par **surfaces publiques uniquement** (`CoachProfile.fromWizardAnswers` / `MinimalProfileService.compute`) — aucun accès aux membres privés `_estimate*`.
- **Baseline RED consignée** (divergence mesurée AVANT fix, via probe jetable supprimée après citation) :

| Cas matrice | Input | coach | minimal | écart |
|---|---|---|---|---|
| salarie_swiss-1 | 42 / 102000 | 113803.81 | 98627.20 | +15.4% |
| cadre_divorce_hypo-2 | 52 / 162000 | 416250.42 | 203022.70 | +105% |
| jeune_diplome-1 (contrôle −) | 25 / 78000 | 0.00 | 0.00 | — |
| returning_swiss_gaps-4 | 48 / 120000 / arrivée 43 | 221308.72 | 155800.42 | divergent |

- RED additionnel (compile) : le test exige `LppCalculator.accumulateAvoir` + le paramètre `arrivalAge` sur `MinimalProfileService.compute`, tous deux introduits au GREEN.

### Task 2 (GREEN) — re-câbler les sites divergents vers LppCalculator
- Commit : `d49651668` — `feat(mint-illogism-fixes-01): unify avoir LPP estimation on LppCalculator`
- **`LppCalculator.accumulateAvoir`** (nouvelle fonction pure, miroir balance-only de `projectToRetirement`) : salaire coordonné clampé [3780, 64260] (LPP art. 8) via `computeSalaireCoordonne`, intérêt registry `lpp.min_interest_rate` (1.25%), bonifications `getLppBonificationRate` (LPP art. 16), `startAge` paramétrable (défaut 25, `arrivalAge` pour expats clampé [25, 65]).
- **`coach_profile._estimateLppAvoir`** : façade déléguant à `accumulateAvoir`. Supprime le clamp min-only (`double.infinity`) — ferme **frontalier-5** — et le rendement 1% hardcodé (`* 1.01`). Conserve `arrivalAge`.
- **`minimal_profile_service._estimateLppBalance`** : façade déléguant à `accumulateAvoir` + nouveau paramètre `int? arrivalAge` plumbé depuis `compute(arrivalAge:)` — ferme **returning_swiss_gaps-4** (démarrage à l'arrivée, plus toujours 25).
- **`monte_carlo_service`** : déjà canonique (lignes 240-241 user / 348-349 conjoint utilisent `computeSalaireCoordonne` + `getLppBonificationRate` registry ; les seuls scalaires inline — mean 0.015 / sd 0.065 — sont des paramètres de distribution Monte Carlo, PAS des constantes LPP réglementaires). **Aucune modification** (Karpathy #3).

## Oracle matrice re-run (GREEN, 0-TRUST §9)

Commande : `cd apps/mobile && flutter test test/services/financial_parity_test.dart`
Sortie : `00:00 +4: All tests passed!` (4/4)

| Cas | Résultat après fix |
|---|---|
| salarie_swiss-1 (42/102000) | valeur UNIQUE sur les 3 chemins (coach == minimal == canonical), salaire coordonné == 64260 (plafonné) |
| cadre_divorce_hypo-2 (52/162000) | parité au centime — écart +105% éliminé |
| jeune_diplome-1 (25/78000) | 0 partout — contrôle négatif PRÉSERVÉ (non régressé) |
| returning_swiss_gaps-4 (48/120000/arrivée 43) | accumulation depuis 43 (~5 ans) < depuis 25 ; coach == minimal == canonicalArrival |

## Verification

| Gate | Commande | Résultat |
|---|---|---|
| Parité W1 | `flutter test test/services/financial_parity_test.dart` | `+4: All tests passed!` |
| Analyse statique | `flutter analyze` | `No issues found! (ran in 16.4s)` |
| Régression services | `flutter test test/services/` | `+5822: All tests passed!` |
| Régression models | `flutter test test/models/` | `+277: All tests passed!` |
| LPP calculator | `flutter test test/services/financial_core/lpp_calculator_test.dart` | `+41: All tests passed!` |
| Golden couple | `flutter test test/golden/golden_couple_validation_test.dart` | `+18: All tests passed!` |
| Golden journeys | `flutter test test/journeys/` | `+213: All tests passed!` |
| Accent lint FR | `accent_lint_fr.py --file <chaque fichier modifié>` | aucune violation |

## Acceptance criteria

- `grep "double.infinity" coach_profile.dart` dans `_estimateLppAvoir` : **0 match** (le seul restant, ligne 455, est dans `lacuneRachatRestante` — clamp buyback `[0, infinity]` non lié, laissé intact par Karpathy #3).
- `grep "1.01"` dans le bloc 3572-3590 : **0 match**.
- `grep -c "LppCalculator\." coach_profile.dart` = **2** (≥1) ; `minimal_profile_service.dart` = **3** (≥1).

## Requirements fermés (9)

salarie_swiss-1, independent_no_lpp-4, expat_us-3, frontalier-2, frontalier-5, cadre_divorce_hypo-2, couple_acheteurs-2, returning_swiss_gaps-3, returning_swiss_gaps-4.

Note : `MATRIX-illogismes-2026-06-09.md` est read-only (contrat) — fermetures consignées ici uniquement.

## Deviations from Plan

- **[Rule 3 - Blocking] Import manquant `lpp_calculator.dart` dans coach_profile.dart**
  - **Found during:** Task 2
  - **Issue:** `coach_profile.dart` importait `tax_calculator.dart` mais pas `lpp_calculator.dart` ; la délégation à `LppCalculator` ne compilait pas.
  - **Fix:** Ajout de `import 'package:mint_mobile/services/financial_core/lpp_calculator.dart';` (ordre alphabétique).
  - **Files modified:** apps/mobile/lib/models/coach_profile.dart
  - **Commit:** d49651668

- **[Surgical scope — pas une déviation de comportement] monte_carlo_service non modifié**
  - Le plan listait `monte_carlo_service.dart` dans `files_modified`, mais le code y était **déjà** canonique (migration antérieure). Aucune constante LPP inline ne subsiste. Conformément à Karpathy #3 (ne pas toucher ce qui n'est pas cassé), le fichier est resté intact. Documenté pour traçabilité.

## Known Stubs

Aucun. Les deux estimateurs produisent des valeurs réelles câblées au canonique ; aucun placeholder / TODO / valeur vide introduit.

## Threat Flags

Aucune nouvelle surface de sécurité. Conforme au threat register du plan : T-ILF-01-01 (Tampering intégrité) et T-ILF-01-02 (Repudiation régression silencieuse) sont **mitigés** par la source unique + le test de parité au centime qui casse la CI à toute régression.

## Self-Check: PASSED

Tous les fichiers créés/modifiés existent sur disque ; les deux commits de tâche (`8a02e8470`, `d49651668`) sont présents dans `git log`.
