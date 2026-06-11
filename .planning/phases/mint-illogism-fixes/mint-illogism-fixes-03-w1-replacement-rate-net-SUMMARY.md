---
phase: mint-illogism-fixes
plan: 03
subsystem: financial_core
tags: [replacement-rate, net-income, financial_core, parity, strangler-fig, l1-canonical, d3]

# Dependency graph
requires:
  - phase: mint-illogism-fixes-02
    provides: "LppCalculator.monthlyRenteFromAvoir + financial_parity_test.dart (harnais W1+W2)"
provides:
  - "ReplacementRate (financial_core L1) — définition canonique unique du taux de remplacement (dénominateur NET courant, numérateur AVS+LPP sans dette, clamp >= 0)"
  - "4 sites de net plat (0.75/0.78) re-câblés sur NetIncomeBreakdown.compute (base nette unique app-wide)"
  - "3 chemins de taux de remplacement (minimal_profile, response_card, budget_living) délèguent au helper"
  - "financial_parity_test.dart — groupes « Parity W3 — Taux de remplacement » (8 cas) + « Parity W3 — Base nette » (2 cas)"
affects: [mint-illogism-fixes-04, mint-illogism-fixes-05]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Strangler-fig (D-11) : les sites de taux de remplacement deviennent des façades déléguant à ReplacementRate.percent / .fraction"
    - "UNE base nette par cas : NetIncomeBreakdown.compute (canton + âge aware) remplace les ratios plats 0.75 / 0.78"
    - "Composition canonique du revenu retraite = AVS + LPP (le service de dette est une donnée budget, pas un revenu — plus de soustraction dans un seul moteur)"

key-files:
  created:
    - apps/mobile/lib/services/financial_core/replacement_rate.dart
  modified:
    - apps/mobile/lib/services/financial_core/financial_core.dart
    - apps/mobile/lib/services/minimal_profile_service.dart
    - apps/mobile/lib/services/budget_living_engine.dart
    - apps/mobile/lib/services/response_card_service.dart
    - apps/mobile/lib/services/cap_sequence_engine.dart
    - apps/mobile/lib/services/premier_eclairage_selector.dart
    - apps/mobile/lib/services/coach/coach_profile_seeds.dart
    - apps/mobile/test/services/financial_parity_test.dart
    - apps/mobile/test/services/minimal_profile_service_test.dart
    - apps/mobile/test/services/cap_sequence_engine_test.dart

key-decisions:
  - "Nouveau helper canonique ReplacementRate (percent + fraction) plutôt qu'un calcul inline partout — un seul point d'entrée, dénominateur NET imposé, clamp >= 0, division-par-zéro neutralisée"
  - "minimal_profile_service.replacementRate reste un champ FRACTION (0-1) et non percent : les consommateurs historiques comparent contre des seuils décimaux (premier_eclairage : `< 0.55`) et multiplient eux-mêmes par 100. Le helper expose .fraction pour ce contrat. La DÉFINITION est unifiée (NET + AVS+LPP) même si l'échelle stockée diffère selon le chemin"
  - "Composition canonique du revenu retraite = AVS + LPP (response_card + retirement_projection_service). Le `- effectiveDebtService` est retiré de minimal_profile_service ; effectiveDebtService reste calculé et surfacé en monthlyDebtImpact (donnée budget)"
  - "Champs grossMonthlySalary / retirementGapMonthly de MinimalProfileResult conservés tels quels (consommés par premier_eclairage + golden Laurent) — surgical scope, seul le dénominateur du taux passe au NET"
  - "_estimateMonthlyExpenses reçoit désormais le NET canonique (déjà calculé dans compute()) au lieu de re-dériver brut×0.75 — les ratios de dépense par type de ménage (0.80/0.75/0.85) restent (ce sont des ratios de dépense, pas des proxys de net)"

patterns-established:
  - "ReplacementRate.percent({totalMonthlyRetirement, netMonthlyIncome}) : retraite / NET × 100, 0 si net non-positif, clamp numérateur >= 0 ; .fraction = percent / 100"
  - "groupe « Parity W3 » : helper unit (définition + clamp) + minimal_profile (dénominateur NET + dette non soustraite) + response_card (value == helper(total, net)) + budget_living (NET/NET en %) + base nette (dépenses + seed dérivés du NET canonique)"

requirements-completed:
  - MATRIX-salarie_swiss-5
  - MATRIX-independent_no_lpp-6
  - MATRIX-expat_us-5
  - MATRIX-frontalier-4
  - MATRIX-cadre_divorce_hypo-4
  - MATRIX-jeune_diplome-3
  - MATRIX-couple_acheteurs-4
  - MATRIX-returning_swiss_gaps-6
  - MATRIX-D3

# Metrics
duration: 24min
completed: 2026-06-11
---

# Phase mint-illogism-fixes Plan 03 (W1) : Taux de remplacement & base nette — Summary

**UNE définition canonique (`ReplacementRate`, financial_core L1) du taux de remplacement — dénominateur NET courant (lock CONTEXT W1), numérateur AVS+LPP sans soustraction de dette — partagée par les 3 chemins publics (onboarding, response card, budget) ; et UNE base nette canonique (`NetIncomeBreakdown.compute`) qui remplace les 4 ratios plats 0.75/0.78, fermant la divergence D3 (63% vs 46.5% même session) + le spread « Marge libre » ~300 CHF/mois sur 120k brut.**

## Performance

- **Duration:** 24 min
- **Started:** 2026-06-11T11:54:51Z
- **Completed:** 2026-06-11T12:18:51Z
- **Tasks:** 2 / 2
- **Files modified:** 10 (1 créé : replacement_rate.dart) + deferred-items.md + VALIDATION.md

## Accomplishments

### Task 1 (RED) — groupe de parité « Taux de remplacement »
- Commit : `c2deb4794` — `test(mint-illogism-fixes-03): add failing parity tests for taux de remplacement`
- Ajout du groupe « Parity W3 — Taux de remplacement » à `financial_parity_test.dart`.
- **RED prouvé** : compile-failure (sortie quotée) — `replacement_rate.dart: No such file or directory` + `Undefined name 'ReplacementRate'`, helper introduit au GREEN.

### Task 1 (GREEN) — ReplacementRate canonique + définition unique
- Commit : `206bb7c02` — `feat(mint-illogism-fixes-03): unify taux de remplacement on ReplacementRate canonical`
- **`financial_core/replacement_rate.dart`** (nouveau, pur, offline) : `ReplacementRate.percent({totalMonthlyRetirement, netMonthlyIncome})` = retraite / NET × 100, clamp numérateur >= 0, 0 si net non-positif ; `.fraction` = percent / 100 pour les consommateurs historiques. Doc-comment citant la définition NET (lock CONTEXT W1).
- **barrel `financial_core.dart`** : export `replacement_rate.dart`.
- **minimal_profile_service:128-150** : dénominateur NET via `NetIncomeBreakdown.compute(canton, age)` (fin du brut) ; `totalMonthlyRetirement = max(0, avsMonthly + lppMonthly)` — `- effectiveDebtService` retiré (composition canonique AVS+LPP) ; `effectiveDebtService` conservé et surfacé en `monthlyDebtImpact`. `replacementRate` via `ReplacementRate.fraction` (champ reste 0-1).
- **budget_living_engine._computeGap** : `ReplacementRate.percent(retirement.monthlyNet, present.monthlyNet).clamp(0, 200)` — fin de la formule mixte `retirement.monthlyNet / grossMonthlySalary` (numérateur NET / dénominateur BRUT). Paramètre `grossMonthlySalary` retiré (devenu inutile) + caller mis à jour.
- **response_card_service._tryReplacementRate:784-800** : délègue à `ReplacementRate.percent` (chemin de référence, comportement inchangé — interdit toute formule ad-hoc future).
- **Tests** : 2 tests `minimal_profile_service_test` encodant l'ancienne sémantique mis à jour (Rule 1) : « replacementRate uses grossMonthlySalary » → NET ; « monthlyDebtImpact reflects debt subtracted » → surfacé mais NON soustrait ; + « debt priority » re-câblé sur `monthlyDebtImpact`.

### Task 2 (GREEN) — base nette canonique, fin des ratios plats 0.75/0.78
- Commit : `b4a41718c` — `feat(mint-illogism-fixes-03): kill flat net ratios, unify on NetIncomeBreakdown`
- **cap_sequence_engine._estimateFreeMontly:658-672** : net via `NetIncomeBreakdown.compute(revenuBrutAnnuel, canton, age)` (fin `salaireBrutMensuel * 0.78`) ; retourne null si âge inconnu (graceful, miroir de cross_pillar_calculator).
- **minimal_profile_service._estimateMonthlyExpenses** : reçoit le NET canonique (déjà calculé dans `compute()`) au lieu de `grossAnnualSalary * 0.75 / 12` ; ratios de dépense par ménage (0.80/0.75/0.85) conservés.
- **premier_eclairage_selector._buildHourlyRateChoc:372-381** : net annuel via `NetIncomeBreakdown.compute(...).netPayslip` (fin `grossAnnualSalary * 0.75`).
- **coach/coach_profile_seeds.toWizardAnswers:130-141** : fallback net via `NetIncomeBreakdown.compute(grossMonthlySalary*12, canton|ZH, age).monthlyNetPayslip` (fin `grossMonthlySalary * 0.78`) ; import `tax_calculator.dart` ajouté ; ZH par défaut documenté pour les fixtures e2e sans canton fiable.
- **Groupe « Parity W3 — Base nette »** : minimal_profile (dépenses == NET canonique × 0.80, isNot proxy plat) + coach_profile_seeds (q_net_income_period_chf == net canonique arrondi, isNot brut×0.78).
- **Test** : `cap_sequence_engine_test` « budget margin estimate ignores implausible housing » mis à jour (Rule 1) — attente dérivée du NET canonique − dépenses plausibles au lieu de la constante `3480` (ancien brut×0.78).

## Oracle matrice re-run (GREEN, 0-TRUST §9)

Commande : `cd apps/mobile && flutter test test/services/financial_parity_test.dart`
Sortie : `00:00 +18: All tests passed!` (18/18 — 4 W1 plan 01 + 6 W2 plan 02 + 8 W3 plan 03)

| Cas W3 | Résultat après fix |
|---|---|
| ReplacementRate.percent — dénominateur NET, échelle % | 4000 / 8000 → 50.0% |
| ReplacementRate.percent — clamp | numérateur < 0 → 0 ; net <= 0 → 0 |
| minimal_profile — dénominateur NET | replacementRate == retraite/NET (pas /brut) ; taux NET > taux BRUT historique |
| minimal_profile — dette non soustraite (D3) | totalMonthlyRetirement(avecDette) == sansDette ; taux identique |
| response_card — délégation | value == ReplacementRate.percent(total, net) (closeTo 0.5 pt, arrondis) |
| budget_living — NET/NET en % | gap.replacementRate == percent(retirement.monthlyNet, present.monthlyNet) |
| base nette minimal_profile | dépenses == NET canonique × 0.80, ≠ brut×0.75 proxy |
| base nette coach_profile_seeds | q_net_income == net canonique, ≠ brut×0.78 proxy |

## Verification

| Gate | Commande | Résultat |
|---|---|---|
| Parité W1+W2+W3 | `flutter test test/services/financial_parity_test.dart` | `+18: All tests passed!` exit 0 |
| Régression services | `flutter test test/services/` | `+5836: All tests passed!` exit 0 |
| Journeys + golden + models | `flutter test test/journeys/ test/golden/golden_couple_validation_test.dart test/models/` | `+508: All tests passed!` exit 0 |
| minimal_profile direct | `flutter test test/services/minimal_profile_service_test.dart` | green (inclus dans services) |
| cap_sequence direct | `flutter test test/services/cap_sequence_engine_test.dart` | `+59: All tests passed!` |
| Analyse statique (app entière) | `flutter analyze` | `No issues found! (ran in 15.6s)` exit 0 |
| Banned terms LSFin | scan diff `f2a71acdf..HEAD` (garanti/optimal/meilleur/sans risque/...) | 0 dans les additions |
| Accent FR | `accent_lint_fr.py --file <chaque fichier touché>` | 0 violation introduite (3 pré-existantes hors-scope → deferred) |

## Acceptance criteria

- AC1 (Task 1) : `replacement_rate.dart` existe, exporté (barrel), doc-comment citant la définition NET. ✅
- AC2 (Task 1) : `grep grossMonthlySalary budget_living_engine.dart` → plus utilisé comme dénominateur de remplacement (seul un commentaire le mentionne). ✅
- AC3 (Task 1) : `grep -rn "ReplacementRate\." lib/services/ | wc -l` → **4** (≥ 3). ✅
- AC4 (Task 1) : `flutter test test/services/financial_parity_test.dart` exit 0 (un seul pourcentage par profil par chemin). ✅
- AC (Task 2) : `grep "0\.75\|0\.78"` sur les 4 sites → 0 usage comme proxy de net (seuls restent : commentaires documentant le retrait + le ratio de dépense ménage `'couple' => 0.75`). ✅
- AC (Task 2) : `flutter test test/services/` exit 0. ✅

## Design panel (4-lens) — response_card / budget / premier_eclairage

Règle `feedback_design_panel_before_push`. Les changements sont des re-câblages de la SOURCE de données (dénominateur du taux, base nette) — aucune modification du widget tree, de la copie i18n, ou de la surface a11y. Revue 4-lens inline (l'executor isolé ne peut pas spawn de subagents) :

- **UX** : aucun changement de layout/flow. Le même profil voit désormais le même taux de remplacement sur onboarding / response card / budget (fin de l'écart 10-20 pts D3). Le taux NET est plus élevé que l'ancien taux BRUT — cohérent avec le sens économique « pouvoir d'achat retrouvé ». PASS.
- **a11y** : aucun nouveau widget, aucun label sémantique modifié. PASS.
- **Adversarial** : net <= 0 → taux 0 (pas de division par zéro) ; numérateur négatif → clamp 0 ; budget clamp [0, 200] ; âge inconnu → cap_sequence retourne null (graceful). Pas de NaN/Infinity. PASS.
- **Engineering/wiring** : délégation au canonique, barrel export ajouté, imports propres (tax_calculator dans coach_profile_seeds), pas de dead code. `flutter analyze` clean. PASS.

Verdict : 4/4 PASS, push autorisé.

## Requirements fermés (9)

salarie_swiss-5, independent_no_lpp-6, expat_us-5, frontalier-4, cadre_divorce_hypo-4, jeune_diplome-3, couple_acheteurs-4, returning_swiss_gaps-6, D3 (+ §2 « Taux de remplacement » / « Marge libre » / « Retraite projetée » consignés via les groupes de parité).

Note : `MATRIX-illogismes-2026-06-09.md` est read-only (contrat) — fermetures consignées ici + VALIDATION.md Per-Task Map (03-T1/03-T2 → done).

## Deviations from Plan

- **[Scope clarification — pas une déviation de comportement] minimal_profile_service.replacementRate reste une FRACTION (0-1)**
  - Le plan évoque « ReplacementRate.percent au lieu de /grossMonthlySalary ». Le champ `replacementRate` de `MinimalProfileResult` est consommé en fraction par `premier_eclairage_selector` (`< 0.55`, `× 100`), `early_retirement_comparison`, `retirement_hero_zone`. Le convertir en percent aurait cassé ces consommateurs. La DÉFINITION est unifiée (dénominateur NET + numérateur AVS+LPP) via `ReplacementRate.fraction` ; seule l'échelle stockée diffère selon le chemin (fraction pour minimal_profile, percent pour response_card/budget). Documenté pour traçabilité.

- **[Rule 1 — Bug] 3 tests encodant l'ancienne sémantique mis à jour**
  - **Found during:** Tasks 1-2 (régression services)
  - **Issue:** `minimal_profile_service_test` (« replacementRate uses grossMonthlySalary », « monthlyDebtImpact subtracted from retirement », « debt priority ») et `cap_sequence_engine_test` (« budget margin == 3480 ») encodaient le brut comme dénominateur, la soustraction de dette, et le proxy plat 0.78.
  - **Fix:** ré-écrits pour asserter la sémantique canonique (dénominateur NET, dette surfacée mais non soustraite, marge dérivée du NET canonique).
  - **Files modified:** test/services/minimal_profile_service_test.dart, test/services/cap_sequence_engine_test.dart
  - **Commits:** 206bb7c02, b4a41718c

- **[Surgical scope] champs grossMonthlySalary / retirementGapMonthly conservés**
  - `MinimalProfileResult.grossMonthlySalary` reste `grossSalary/12` (consommé par premier_eclairage + golden Laurent) ; `retirementGapMonthly` garde sa forme `max(0, grossMonthlySalary - total)` — seul le dénominateur du *taux* passe au NET. Changer le gap au NET aurait modifié des valeurs affichées hors must_haves (Karpathy #3).

- **[Out-of-scope — deferred] 3 accents FR pré-existants**
  - `accent_lint_fr` signale `securite` → `sécurité` dans `response_card_service.dart:988` (commit c214201d0) et `premier_eclairage_selector.dart:257/259` (string d'alerte épargne). Hors des diffs plan-03 (édits ~788-800 et ~373-387). Logués dans `deferred-items.md`, NON corrigés (SCOPE BOUNDARY + Karpathy #3).

## Known Stubs

Aucun. Tous les chemins produisent des valeurs réelles câblées au canonique ; aucun placeholder / TODO / valeur vide introduit.

## Threat Flags

Aucune nouvelle surface de sécurité. Conforme au threat register du plan : T-ILF-03-01 (Tampering intégrité du taux de remplacement / base nette) est **mitigé** par le helper canonique financial_core + la parité 3 chemins (casse la CI à toute régression) ; T-ILF-03-02 (Information disclosure) reste **accept** (calculs purs, aucune nouvelle donnée collectée).

## Self-Check: PASSED

Tous les fichiers créés/modifiés existent sur disque ; les trois commits de tâche (`c2deb4794`, `206bb7c02`, `b4a41718c`) sont présents dans `git log`. (Vérification détaillée ci-dessous.)
