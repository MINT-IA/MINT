---
phase: mint-illogism-fixes
plan: 04
subsystem: financial_core
tags: [pillar-3a, independant, net-income, opp3, financial_core, parity, l1-canonical, lsfin]

# Dependency graph
requires:
  - phase: mint-illogism-fixes-03
    provides: "NetIncomeBreakdown.compute (base nette canonique app-wide) + financial_parity_test.dart (harnais W1-W3)"
provides:
  - "estimate3aTaxImpact (financial_core L1) — branche hasLpp=false calculée sur le revenu professionnel NET (OPP3 art. 7 al. 2), fournie OU dérivée via NetIncomeBreakdown ; plus jamais sur le brut nu"
  - "minimal_profile_service — passe le NET canonique + age à estimate3aTaxImpact ; fallback net×0.20 (plus brut×0.20)"
  - "financial_parity_test.dart — groupe « Parity W4 — Plafond 3a indépendant » (4 cas) : parité tax_calculator == independants_service"
affects: [mint-illogism-fixes-07]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "UNE base app-wide pour le plafond 3a indépendant : 20% du revenu professionnel NET (OPP3 art. 7 al. 2), borné 36288 — plus jamais le brut nu (independent_no_lpp-1)"
    - "Parité inter-moteurs : estimate3aTaxImpact converge sur IndependantsService.calculate3aIndependant (référence déjà sur le net) — fin de la classe DIVERGENT (independent_no_lpp-2)"
    - "netDerive interne via NetIncomeBreakdown.compute quand l'appelant ne fournit pas netProfessionalIncome : tous les chemins no-LPP (first_job, premier_eclairage, report_builder, coach_narrative…) bénéficient du fix sans changement de signature côté appelant"

key-files:
  created: []
  modified:
    - apps/mobile/lib/services/financial_core/tax_calculator.dart
    - apps/mobile/lib/services/minimal_profile_service.dart
    - apps/mobile/test/services/financial_parity_test.dart
    - apps/mobile/test/services/minimal_profile_service_test.dart

key-decisions:
  - "Ajout de `double? netProfessionalIncome` + `int age = 45` à estimate3aTaxImpact (paramètres optionnels, non-breaking). La branche hasLpp=false = (netProfessionalIncome ?? NetIncomeBreakdown.compute(...).netPayslip) × 0.20, borné 36288. Le fix est centralisé DANS l'engine : les ~7 callers no-LPP (first_job, premier_eclairage, financial_report, report_builder, coach_narrative, focus_selector) cessent de calculer sur le brut sans aucun changement chez eux"
  - "minimal_profile_service ré-emploie le NET canonique déjà calculé pour le taux de remplacement (netMonthlyIncome × 12) comme base nette professionnelle de l'indépendant — pas de re-dérivation, une seule base nette par cas"
  - "independants_service.calculate3aIndependant (référence, déjà sur le net) NON touché — c'est la cible de convergence, pas la chose à corriger (plan explicite)"
  - "Le paramètre `age` ne sert QUE quand netProfessionalIncome est absent (dérivation du net) — il n'altère pas le plafond avec-LPP (forfait fixe 7258)"

patterns-established:
  - "groupe « Parity W4 — Plafond 3a indépendant » : (1) net pro 86400 → 17280 sur les deux moteurs + isNot(21600 brut) ; (2) contrôle négatif hasLpp=true → 7258 ; (3) net absent → dérivé NET + lessThan(brut×0.20) ; (4) minimal_profile indépendant → plafond3a sur NET dérivé + isNot(brut×0.20)"

requirements-completed:
  - MATRIX-independent_no_lpp-1
  - MATRIX-independent_no_lpp-2

# Metrics
duration: 7min
completed: 2026-06-11
---

# Phase mint-illogism-fixes Plan 04 (W1) : Plafond 3a indépendant base nette — Summary

**Le plafond 3a d'un indépendant sans LPP est désormais calculé sur le revenu professionnel NET (OPP3 art. 7 al. 2) sur TOUS les chemins — `estimate3aTaxImpact` (financial_core L1) prend une base NET (fournie ou dérivée via `NetIncomeBreakdown`) au lieu du brut nu, fermant le finding WRONG independent_no_lpp-1 (+25% de sur-promesse de déduction) et le finding DIVERGENT independent_no_lpp-2 (deux moteurs, deux bases). Pour un net pro 86400 : plafond = 17280 partout (plus jamais 21600 calculé sur le brut 108000). Le contrôle négatif salarié-LPP (7258) reste intact.**

## Performance

- **Duration:** 7 min
- **Started:** 2026-06-11T12:25:20Z
- **Completed:** 2026-06-11T12:32:35Z
- **Tasks:** 1 / 1 (TDD : RED → GREEN, pas de REFACTOR nécessaire)
- **Files modified:** 4 (0 créé) + deferred-items.md + VALIDATION.md

## Accomplishments

### Task 1 (RED) — groupe de parité « Plafond 3a indépendant »
- Commit : `585ca3085` — `test(mint-illogism-fixes-04): add failing parity tests for plafond 3a indépendant base nette`
- Ajout du groupe « Parity W4 — Plafond 3a indépendant » à `financial_parity_test.dart` (4 cas) + import `IndependantsService`.
- **RED prouvé** : compile-failure (sortie quotée) — `tax_calculator.dart:532 No named parameter with the name 'netProfessionalIncome'` + `'age'`. Les nouveaux paramètres n'existent pas encore.

### Task 1 (GREEN) — base NET dans estimate3aTaxImpact + plumbing minimal_profile_service
- Commit : `37a6221ad` — `feat(mint-illogism-fixes-04): plafond 3a indépendant sur base NET partout`
- **`financial_core/tax_calculator.dart` (estimate3aTaxImpact)** : ajout de `double? netProfessionalIncome` + `int age = 45`. La branche `hasLpp == false` devient `(netProfessionalIncome ?? NetIncomeBreakdown.compute(gross, canton, age, etatCivil, nombreEnfants).netPayslip) × pilier3aTauxRevenuSansLpp, borné [0, pilier3aPlafondSansLpp]`. **Plus aucun `grossAnnualSalary * pilier3aTauxRevenuSansLpp`** (grep = 0). Le fix est CENTRALISÉ dans l'engine : tous les callers no-LPP en bénéficient sans changer leur signature.
- **`minimal_profile_service.dart`** : pour l'indépendant sans LPP, `netProfessionalIncome = netMonthlyIncome × 12` (NET canonique déjà calculé pour le taux de remplacement, plan 03) + `age` passés à `estimate3aTaxImpact`. Le fallback (cas canton non résolu) corrigé : `min((netProfessionalIncome ?? 0) × pilier3aTauxRevenuSansLpp, pilier3aPlafondSansLpp)` au lieu de `grossSalary × 0.20`.
- **`independants_service.dart:412`** (référence, déjà `min(revenuNet × 0.20, 36288)`) **NON touché** — c'est la cible de convergence.
- **Rule 1** : 2 tests `minimal_profile_service_test` encodant l'ancienne base brut mis à jour (NET) — voir Deviations.

## Oracle matrice re-run (GREEN, 0-TRUST §9)

Commande : `cd apps/mobile && flutter test test/services/financial_parity_test.dart`
Sortie : `00:00 +22: All tests passed!` (22/22 — 4 W1 plan 01 + 6 W2 plan 02 + 8 W3 plan 03 + 4 W4 plan 04)

| Cas W4 | Résultat après fix |
|---|---|
| independent_no_lpp-1/-2 — net pro 86400 | annualCeiling == 17280 sur tax_calculator ET independants_service ; isNot(21600 = brut×0.20) ; parité inter-moteurs |
| contrôle négatif — hasLpp=true | annualCeiling == 7258 (forfait fixe inchangé) |
| net absent (null) | plafond dérivé du NET (NetIncomeBreakdown) ; lessThan(brut×0.20) |
| minimal_profile — indépendant sans LPP | plafond3a == NET dérivé × 0.20 ; isNot(brut×0.20) |

## Verification

| Gate | Commande | Résultat |
|---|---|---|
| Pas de base brut résiduelle | `grep -n "grossAnnualSalary \* pilier3aTauxRevenuSansLpp" tax_calculator.dart` | exit 1 (0 résultat) |
| Parité W1+W2+W3+W4 | `flutter test test/services/financial_parity_test.dart` | `+22: All tests passed!` exit 0 |
| Régression services | `flutter test test/services/` | `+5840: All tests passed!` exit 0 |
| Journeys + golden + models | `flutter test test/journeys/ test/golden/golden_couple_validation_test.dart test/models/` | `+508: All tests passed!` exit 0 |
| Analyse statique (app entière) | `flutter analyze` | `No issues found! (ran in 15.6s)` exit 0 |
| Banned terms LSFin | scan diff `585ca3085..HEAD` (garanti/optimal/meilleur/sans risque/…) | 0 dans les additions |
| Accent FR | `accent_lint_fr.py --file <chaque fichier touché>` | 0 violation introduite (1 pré-existante hors-scope tax_calculator.dart:263 → deferred) |

## Acceptance criteria

- AC1 (Task 1) : `grep "grossAnnualSalary * pilier3aTauxRevenuSansLpp" tax_calculator.dart` → 0 résultat. ✅
- AC2 (Task 1) : `flutter test test/services/financial_parity_test.dart` exit 0 (86400 net → 17280 sur les deux moteurs ; 7258 inchangé pour hasLpp=true). ✅
- AC3 (Task 1) : `flutter analyze && flutter test test/services/` exit 0 (tests des sites touchés mis à jour, pas contournés — 2 tests minimal_profile ré-écrits sur la base NET). ✅

## Design panel (4-lens)

Règle `feedback_design_panel_before_push`. Le changement est un re-câblage de la BASE de calcul (plafond 3a indépendant : brut → net) — aucune modification du widget tree, de la copie i18n, ou de la surface a11y. Revue 4-lens inline (l'executor isolé ne peut pas spawn de subagents) :

- **UX** : aucun changement de layout/flow. Un indépendant voit désormais un plafond 3a plus bas (correct OPP3 art. 7 al. 2) et identique quel que soit l'écran — fin de la sur-promesse de déduction de +25%. PASS.
- **a11y** : aucun nouveau widget, aucun label sémantique modifié. PASS.
- **Adversarial** : gross ≤ 0 → unavailable (early return inchangé) ; net dérivé borné [0, 36288] ; clamp identique à la référence independants_service ; pas de NaN/Infinity ; paramètres nouveaux optionnels (non-breaking). PASS.
- **Engineering/wiring** : fix centralisé dans l'engine financial_core (CLAUDE.md NEVER #3 respecté, L1 canonical) ; les ~7 callers no-LPP convergent sans changement ; imports propres ; `flutter analyze` clean. PASS.

Verdict : 4/4 PASS, push autorisé.

## Requirements fermés (2)

independent_no_lpp-1 (WRONG : plafond sur le brut) + independent_no_lpp-2 (DIVERGENT : tax_calculator sur brut vs independants_service sur net). Aucun chemin restant ne calcule le plafond indépendant sur le brut (grep AC1 = 0 ; les callers no-LPP héritent du netDerive interne).

Note : `MATRIX-illogismes-2026-06-09.md` est read-only (contrat) — fermetures consignées ici + VALIDATION.md Per-Task Map (04-T1 → done).

## Deviations from Plan

- **[Rule 1 — Bug] 2 tests minimal_profile encodant l'ancienne base BRUT mis à jour**
  - **Found during:** Task 1 GREEN (régression services)
  - **Issue:** `minimal_profile_service_test` — « independant sans LPP: ... plafond = min(20% revenu, 36288) » assertait `plafond3a == 20000` (= 100k brut × 0.20) et le cas haut-revenu, + « independent no-LPP taxSaving3a uses 20% income ceiling » assertait `plafond3a == 10000` (= 50k brut × 0.20). Les deux encodaient le brut comme base — exactement le bug corrigé (independent_no_lpp-1).
  - **Fix:** ré-écrits pour asserter le plafond canonique = 20% du NET dérivé via `NetIncomeBreakdown` (borné 36288), avec une régression explicite `isNot(brut×0.20)` sur chaque. Valeurs observées : 100k brut GE → 17756.10 (vs 20000 brut) ; 50k brut VD → 9006.90 (vs 10000 brut).
  - **Files modified:** test/services/minimal_profile_service_test.dart
  - **Commit:** 37a6221ad

- **[Scope clarification — pas une déviation de comportement] paramètre `age` ajouté à estimate3aTaxImpact**
  - Le plan évoque « netDerive vient de NetIncomeBreakdown.compute ». `NetIncomeBreakdown.compute` requiert un `age` (LPP coordonné, âge-aware). Comme `estimate3aTaxImpact` n'avait pas d'`age`, j'ai ajouté `int age = 45` (optionnel, défaut représentatif), utilisé UNIQUEMENT pour dériver le net quand `netProfessionalIncome` est absent. minimal_profile passe son `age` réel. Aucun impact sur la branche avec-LPP (forfait fixe 7258).

- **[Out-of-scope — deferred] 1 accent FR pré-existant**
  - `accent_lint_fr` signale `specialiste` → `spécialiste` + `personnalisee` dans `tax_calculator.dart:263` (string de disclaimer fiscal, commit `923a1a7e6`). Hors du diff plan-04 (édit limité à `estimate3aTaxImpact` ~532-570). Logué dans `deferred-items.md`, NON corrigé (SCOPE BOUNDARY + Karpathy #3).

## Known Stubs

Aucun. Le plafond produit une valeur réelle câblée au NET canonique sur tous les chemins ; aucun placeholder / TODO / valeur vide introduit.

## Threat Flags

Aucune nouvelle surface de sécurité. Conforme au threat register du plan : T-ILF-04-01 (Tampering — intégrité de la branche plafond sans-LPP) est **mitigé** par la base nette + la parité inter-moteurs (casse la CI à toute régression vers le brut) + le contrôle négatif 7258 (preuve que le forfait avec-LPP reste intact).

## Self-Check: PASSED

Tous les fichiers modifiés existent sur disque (tax_calculator.dart, minimal_profile_service.dart, financial_parity_test.dart, minimal_profile_service_test.dart + ce SUMMARY) ; les deux commits de tâche (`585ca3085` RED, `37a6221ad` GREEN) sont présents dans `git log`.
