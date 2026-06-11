---
phase: mint-illogism-fixes
plan: 14
subsystem: coach-context / budget-engine
tags: [pillar-3a, suggestion-cap, coach-context, lsfin, D10, financial_core, l1-canonical]

# Dependency graph
requires:
  - phase: mint-illogism-fixes-04
    provides: "Pillar3aRoomCalculator.annualCeiling base NET indépendant (plafond canonique)"
  - phase: mint-illogism-fixes-08
    provides: "annualCeiling FATCA-gated → 0.0 quand canContribute3a est false (US person)"
  - phase: mint-illogism-fixes-11
    provides: "confiance canonique (dépendance déclarée plan ; non touchée ici)"
provides:
  - "BudgetLivingEngine.cappedMonthly3aSuggestion(profile, availableMonthlyMargin, archetype?, now?) — suggestion 3a mensuelle plafonnée = min(margeDisponible, plafondRestant/moisRestants) ; room 0 → 0.0 (aucune suggestion)"
  - "context_injector_service BUDGET VIVANT — injecte le versement 3a CAPPÉ (pas la marge libre nue) pour que le coach LLM ne dérive jamais un versement supra-plafond"
affects: []

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Toute suggestion de versement 3a passe par le plafond canonique RESTANT (Pillar3aRoomCalculator.remainingAnnualRoom) pro-raté sur les mois restants de l'année civile — jamais la marge libre nue (D10)"
    - "Plafond restant 0 (US person FATCA OU plafond atteint) ⇒ 0.0 = AUCUNE suggestion 3a, pas une suggestion dissonante à 0 CHF"
    - "Le clamp réutilise financial_core L1 (Pillar3aRoomCalculator) via le barrel financial_core.dart — pas de re-dérivation du plafond (CLAUDE.md NEVER #3)"

key-files:
  created:
    - apps/mobile/test/services/suggestion_3a_cap_test.dart
  modified:
    - apps/mobile/lib/services/budget_living_engine.dart
    - apps/mobile/lib/services/coach/context_injector_service.dart
    - .planning/phases/mint-illogism-fixes/mint-illogism-fixes-VALIDATION.md

key-decisions:
  - "Site réel de D10 (Task 1) = l'INJECTION de contexte coach, pas le moteur de budget. budget_living_engine Cap 2 « 3a_max » plafonnait DÉJÀ correctement (plafondMensuel) et les openers budgetRoom/savingsOpportunity/deadlineUrgency utilisaient déjà Pillar3aRoomCalculator. Le trou : context_injector_service.dart:331 injectait « Marge libre : 1541/mois » SANS plafond 3a, laissant le LLM dériver « verser ta marge libre (1541) en 3a » (×12 ≈ 2.55× le plafond 7258)"
  - "Fix : nouvelle méthode pure BudgetLivingEngine.cappedMonthly3aSuggestion = min(margeDisponible, plafondRestant/moisRestants) où moisRestants = 13 − mois courant (janvier→12, décembre→1). Câblée dans le bloc BUDGET VIVANT du context injector : le coach reçoit le montant DÉJÀ plafonné + une consigne explicite « ne jamais suggérer plus que ce montant en 3a, ni la marge libre entière »"
  - "room ≤ 0 → 0.0. Pour un US person (annualCeiling 0.0 depuis plan 08), remainingAnnualRoom est 0 ⇒ la ligne injectée devient « Versement 3a suggérable : 0 (… non-éligible) — ne pas suggérer de versement 3a ». Un plafond 0 = AUCUNE suggestion, pas une suggestion à 0 CHF (note du plan honorée)"
  - "Indépendant sans LPP : le clamp suit SON plafond (net×0.20 ≤ 36288, plan 04), pas le forfait 7258 — vérifié par test (17280/12 = 1440)"
  - "Aucune clé ARB ajoutée : le texte injecté entre dans le PROMPT LLM (français en dur, conforme aux ~20 lignes de prompt existantes de context_injector_service), pas dans une surface UI user-facing. Donc PAS de collision de wave ARB avec le plan 15 (la note du plan est respectée a contrario)"

requirements-completed:
  - MATRIX-D10

# Metrics
duration: 7min
completed: 2026-06-11
---

# Phase mint-illogism-fixes Plan 14 (W4) : Suggestion 3a plafonnée — Summary

**La suggestion mensuelle « tu pourrais verser X en 3a » est désormais plafonnée au plafond légal annuel RESTANT (plafond canonique du plan 04, FATCA-gated du plan 08), pro-raté sur les mois restants de l'année civile, et capée par la marge disponible : `min(margeDisponible, plafondRestant/moisRestants)`. Le finding device D10 (« verser 1541 CHF/mois » Marc / « 1462 » profil 2 — ×12 ≈ 2.4-2.55× le plafond 7258, jamais mentionné) est fermé. Diagnostic Task 1 : le trou n'était PAS le moteur de budget (Cap 2 « 3a_max » plafonnait déjà) mais l'injection de contexte coach (`context_injector_service.dart:331`) qui livrait « Marge libre : 1541/mois » au LLM sans aucun plafond 3a, le laissant dériver une suggestion supra-plafond. Le coach reçoit maintenant le montant DÉJÀ plafonné + la consigne explicite de ne jamais suggérer plus. Plafond 0 (US person / plafond atteint) ⇒ AUCUNE suggestion.**

## Performance

- **Duration:** 7 min
- **Started:** 2026-06-11T19:32:40Z
- **Completed:** 2026-06-11
- **Tasks:** 2 / 2 (Task 1 diagnostic ; Task 2 TDD RED → GREEN, pas de REFACTOR)
- **Files modified:** 2 + 1 test créé + VALIDATION.md

## Task 1 — Diagnostic (oracle grep), aucune modification

Tracé du chemin « surface Mon Argent/futur → suggestion 3a depuis la marge libre » :

| Candidat | Verdict | Citation |
|---|---|---|
| `budget_living_engine.dart:302-322` (Cap 2 « 3a_max ») | **DÉJÀ plafonné** — `plafondMensuel = pillar3a.max_with_lpp / 12` ; `additional3aMonthly = plafondMensuel − current3aMensuel`. Ne produit JAMAIS 1541. | `budget_living_engine.dart:304-308` |
| openers `budgetRoom` / `savingsOpportunity` / `deadlineUrgency` | **DÉJÀ corrects** — `savingsOpportunity`/`deadlineUrgency` utilisent `Pillar3aRoomCalculator.remainingAnnualRoom` (clampé) ; `budgetRoom` dit « Il te reste X CHF après tes charges » (pas une suggestion 3a). | `precomputed_insights_service.dart:344,364` ; `data_driven_opener_service.dart:227,277` |
| **`context_injector_service.dart:331`** | **TROU RÉEL** — injecte `Marge libre : ${monthlyFree}/mois` dans le bloc BUDGET VIVANT du prompt coach, SANS aucune ligne de plafond 3a. Le LLM reçoit 1541 nu → dérive « verser ta marge libre (1541) en 3a ». | `context_injector_service.dart:330-331` |

**Reproduction statique de 1541** : `monthlyFree = monthlyNet − monthlyCharges − monthlySavings` (`budget_living_engine.dart:153`). Pour un profil Marc-like à marge ~1541, ×12 = 18 492 ≈ 2.55× le plafond avec-LPP 7258 — cohérent avec la ligne matrice D10 (« ≈2.4× »).

> **Déviation `files_modified`** : le plan nommait `budget_living_engine.dart`. Le site réel de la fuite est `context_injector_service.dart`. J'ai étendu le périmètre (la note du plan l'autorise explicitement : « Si le site réel diffère, l'étendre et le documenter dans le SUMMARY ») : le clamp canonique vit dans `budget_living_engine` (méthode pure, testable, financial_core-adjacent) ET est câblé dans `context_injector_service` (le site de la fuite).

## Task 2 — Clamp au plafond légal restant (TDD)

### RED — `24688cc9f`
- `test(mint-illogism-fixes-14): add failing test for capped 3a monthly suggestion (D10)`
- `test/services/suggestion_3a_cap_test.dart` (8 cas, 193 lignes ≥ min_lines 30).
- **RED prouvé** : compile-failure quotée — `Member not found: 'BudgetLivingEngine.cappedMonthly3aSuggestion'`.

### GREEN — `1f4318519`
- `feat(mint-illogism-fixes-14): clamp 3a suggestion to remaining statutory ceiling (D10)`
- **`budget_living_engine.dart`** : `static double cappedMonthly3aSuggestion(profile, {required availableMonthlyMargin, archetype?, now?})` :
  - `availableMonthlyMargin <= 0` → `0.0` (déficit, rien à suggérer).
  - `remainingRoom = Pillar3aRoomCalculator.remainingAnnualRoom(profile, archetype)` (canonique, via le barrel `financial_core.dart` déjà importé).
  - `remainingRoom <= 0` → `0.0` (US person FATCA-gated plan 08 OU plafond atteint = AUCUNE suggestion).
  - sinon `min(availableMonthlyMargin, remainingRoom / monthsRemaining)`, `monthsRemaining = (13 − now.month).clamp(1,12)`.
- **`context_injector_service.dart`** : import de `BudgetLivingEngine` + dans le bloc BUDGET VIVANT, ligne injectée du versement 3a CAPPÉ (avec mention explicite du plafond légal restant) ; si capped = 0, ligne « ne pas suggérer de versement 3a ». Le LLM ne reçoit plus jamais la marge libre nue sans son plafond 3a associé.

## Oracle D10 (re-run statique, 0-TRUST §9)

Commande : `cd apps/mobile && flutter test test/services/suggestion_3a_cap_test.dart`
Sortie : `00:00 +8: All tests passed!` (8/8)

| Cas | Avant (D10) | Après fix |
|---|---|---|
| Marge 1541, plafond 7258, versé 0, janvier | suggestion 1541 (×12 ≈ 2.55× plafond) | ≤ 605/mois (= 7258/12 ≈ 604.83), `isNot(1541)` |
| Marge 1462 (profil 2), janvier | suggestion 1462 | ≤ 605/mois, `isNot(1462)` |
| Marge basse 300 < plafond/mois | — | 300 (la marge gouverne, on ne suggère jamais plus que la marge) |
| Plafond atteint (3a complet 605/mois) | suggestion ~marge | 0.0 (pas de versement) |
| US person (FATCA, plafond 0 plan 08) | risque de suggestion illégale | 0.0 (AUCUNE suggestion 3a) |
| Indépendant sans LPP (net 86400 → plafond 17280) | clampé à 7258 (faux) | 1440/mois (= 17280/12), `> 7258/12` |
| Décembre (1 mois restant), marge 1541 | — | 1541 (plafond restant/1 >> marge → la marge gouverne ; un seul versement ≤ plafond reste légal) |
| Marge négative (déficit) | — | 0.0 |

## Verification (0-TRUST §9 — citations déterministes)

| Gate | Commande | Résultat |
|---|---|---|
| Test ciblé | `flutter test test/services/suggestion_3a_cap_test.dart` | `+8: All tests passed!` exit 0 |
| Régression services | `flutter test test/services/` | `+5882: All tests passed!` exit 0 |
| Régression context injector | `flutter test test/services/context_injector_service_test.dart` (incl. « Budget Vivant context formats CHF amounts ») | passe (dans les 5882) |
| Régression room calculator | `flutter test test/services/financial_core/pillar3a_room_calculator_test.dart` | passe (dans les 5882) |
| Analyse statique (fichiers touchés) | `flutter analyze lib/services/budget_living_engine.dart lib/services/coach/context_injector_service.dart test/services/suggestion_3a_cap_test.dart` | `No issues found!` exit 0 |
| Accent FR | `accent_lint_fr.py --file <3 fichiers touchés>` | exit 0 (0 violation) |
| Banned terms LSFin | scan additions `24688cc9f..HEAD` (garanti/optimal/meilleur/sans risque/parfait/…) | 0 dans les additions |

## Acceptance criteria

- AC Task 1 : site(s) cités file:line + reproduction statique de 1541 (`monthlyFree` ligne 153, ×12 ≈ 2.55× plafond). ✅
- AC Task 2 (1) : `flutter test test/services/suggestion_3a_cap_test.dart` exit 0. ✅
- AC Task 2 (2) — oracle D10 re-run sur sim, capture `.planning/_walker/illogism-fixes/w4/` : **déféré à l'orchestrateur** (NO_BOOTED_SIM + contrainte build worktree .nosync — précédent W1-W4, cf. lignes 53/59/65/67/69 de VALIDATION.md). Le clamp est prouvé déterministe (test unitaire 8/8) ; le device-proof inversé (Marc → ≤ 605/mois) est à logger par l'orchestrateur post-build.

## Design panel (4-lens, inline)

Règle `feedback_design_panel_before_push`. Le changement est (1) une fonction pure de calcul + (2) une ligne de PROMPT coach — aucune modification du widget tree, de la copie UI user-facing, ou de la surface a11y. Revue 4-lens inline (executor séquentiel sans spawn de subagents) :

- **UX** : le coach ne suggère plus un versement 3a illégal (2.55× plafond). Il propose un montant plafonné réaliste, ou redirige sans promesse quand le plafond est atteint. PASS.
- **a11y** : aucun widget, aucun label sémantique modifié (le texte va dans le prompt LLM). PASS.
- **Adversarial** : marge ≤ 0 → 0 ; room ≤ 0 (US person / plafond atteint) → 0 ; décembre 1 mois → la marge gouverne, jamais > plafond annuel sur un versement ponctuel ; pas de NaN/division par zéro (`monthsRemaining.clamp(1,12)`). PASS.
- **Engineering/wiring** : réutilise `Pillar3aRoomCalculator` L1 canonique via le barrel (NEVER #3 respecté) ; archétype-aware ; non-breaking (nouvelle méthode + une ligne d'injection guardée `profile != null && monthlyFree > 0`) ; `flutter analyze` clean. PASS.

Verdict : 4/4 PASS.

## Requirements fermés (1)

MATRIX-D10 (Suggestion 3a sur-plafond reproductible). Plus aucun chemin n'injecte la marge libre nue comme suggestion 3a au coach ; le seul nombre 3a-suggérable transmis est le montant plafonné. `MATRIX-illogismes-2026-06-09.md` est read-only (contrat) — fermeture consignée ici + VALIDATION.md (14-T1, 14-T2 → done).

## Deviations from Plan

- **[Rule 3 — site réel localisé hors `files_modified`] le fix vit dans `context_injector_service.dart`, pas seulement `budget_living_engine.dart`**
  - **Found during:** Task 1 (diagnostic).
  - **Issue:** `budget_living_engine` Cap 2 « 3a_max » plafonnait déjà correctement ; le finding D10 venait de l'injection brute de la marge libre dans le contexte coach (`context_injector_service.dart:331`), laissant le LLM dériver une suggestion supra-plafond.
  - **Fix:** clamp canonique ajouté à `budget_living_engine` (méthode pure testable) + câblé dans `context_injector_service` (site de la fuite). Périmètre étendu conformément à la note explicite du plan (« Si le site réel diffère, l'étendre et le documenter dans le SUMMARY »).
  - **Files modified:** budget_living_engine.dart, context_injector_service.dart.
  - **Commit:** 1f4318519.

- **[Scope — pas une déviation de comportement] aucune clé ARB ajoutée**
  - Le texte de suggestion plafonnée entre dans le PROMPT LLM (français en dur, conforme aux lignes de prompt existantes de context_injector_service), pas dans une surface UI user-facing. Donc aucune dépendance ARB et **aucune collision de wave 12 avec le plan 15** (la garde du plan « pas de fichier ARB partagé en wave 12 » est respectée a contrario : il n'y a pas de fichier ARB du tout).

## Known Stubs

Aucun. La méthode produit une valeur réelle dérivée du plafond canonique + de la marge réelle ; aucun placeholder / TODO / valeur vide introduit.

## Threat Flags

Aucune nouvelle surface de sécurité. Conforme au threat register : T-ILF-14-01 (Tampering — intégrité du conseil) est **mitigé** par le clamp au plafond canonique + le test (8 cas, casse la CI à toute régression vers la marge nue) + la gate room-0 (US person / plafond atteint → aucune suggestion).

## Self-Check: PASSED

- Fichiers existent sur disque : `apps/mobile/lib/services/budget_living_engine.dart`, `apps/mobile/lib/services/coach/context_injector_service.dart`, `apps/mobile/test/services/suggestion_3a_cap_test.dart`, ce SUMMARY — tous présents.
- Commits présents dans `git log` : `24688cc9f` (RED), `1f4318519` (GREEN).
