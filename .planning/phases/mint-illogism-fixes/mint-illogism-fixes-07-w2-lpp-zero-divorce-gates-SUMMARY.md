---
phase: mint-illogism-fixes
plan: 07
subsystem: financial-core
tags: [flutter, financial-core, lpp, archetype-gate, divorce, independant, i18n, parity]

# Dependency graph
requires:
  - phase: mint-illogism-fixes-06
    provides: q_employment_status / q_civil_status (incl. divorce) peuplés à l'onboarding
provides:
  - ArchetypePredicates (financial_core L1) — gate LPP=0 partagé consommé par les deux moteurs de profil
  - PrevoyanceProfile.lppEstimationBlocked — état « valeur réelle requise » pour un divorcé sans valeur saisie
  - clé ARB lppEstimationBlockedRealValueRequired ×6 langues (FR/EN/DE/ES/IT/PT)
affects: [mint-illogism-fixes-08, mint-illogism-fixes-11, coach-profile-archetype-resolution]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Gate financier partagé en financial_core L1 (ArchetypePredicates) consommé par minimal_profile_service ET coach_profile — un seul prédicat, deux moteurs, parité testée (CLAUDE.md NEVER #3)"
    - "Règle d'or independant : l'ESTIMATION âge×salaire est interdite même quand hasPensionFund==true ; seule une valeur réelle saisie/scannée (_coach_avoir_lpp) compte"
    - "État inestimable exposé via flag booléen sur le modèle (lppEstimationBlocked) + avoirLppTotal null — la dégradation de confiance se fait automatiquement via le ConfidenceScorer existant (completeness)"

key-files:
  created:
    - apps/mobile/lib/services/financial_core/archetype_predicates.dart
  modified:
    - apps/mobile/lib/services/financial_core/financial_core.dart
    - apps/mobile/lib/services/minimal_profile_service.dart
    - apps/mobile/lib/models/coach_profile.dart
    - apps/mobile/lib/l10n/app_*.arb (6 langues) + generated app_localizations*.dart (7)
    - apps/mobile/test/services/financial_parity_test.dart

key-decisions:
  - "Le bug du gate non-équivalent (independent_no_lpp-3) se ferme via canEstimateLppByEmployment : un indépendant ne reçoit JAMAIS un avoir ESTIMÉ, même en répondant « oui » à q_has_pension_fund. Le gate ne porte plus sur le free-standing q_has_pension_fund."
  - "Le gate divorcé (cadre_divorce_hypo-1) laisse avoirLppTotal=null (inestimable, CC art.122) plutôt qu'un 0 trompeur ; lppEstimationBlocked=true signale l'état « valeur réelle requise » à l'UI hero (plan 11)."
  - "La dégradation de confiance n'a pas eu besoin de nouveau code : avoirLppTotal null fait tomber le ConfidenceScorer dans la branche « avoir LPP non renseigné » (completeness baisse de 18 pts), prouvé par test."

patterns-established:
  - "Prédicat d'archétype partagé en financial_core L1, importé par les deux moteurs de profil, parité au centime encodée dans financial_parity_test.dart"

requirements-completed: [MATRIX-independent_no_lpp-3, MATRIX-cadre_divorce_hypo-1]

# Metrics
duration: ~11min
completed: 2026-06-11
---

# Phase mint-illogism-fixes Plan 07: W2 Gates LPP — prédicat LPP=0 unifié + interdiction d'estimation pour un divorcé Summary

**Un prédicat LPP unique (`ArchetypePredicates`, financial_core L1) est désormais consommé par les deux moteurs de profil : un indépendant ne reçoit plus jamais d'avoir LPP estimé (fin du gate non-équivalent `q_has_pension_fund` qui attribuait ~76-95k de LPP fantôme), et un divorcé sans valeur réelle n'est plus estimé par âge×salaire (fin de l'avoir certain de 416k — CC art.122) mais flaggé « valeur réelle requise » avec confiance dégradée.**

## Performance

- **Duration:** ~11 min
- **Completed:** 2026-06-11T16:06Z
- **Tasks:** 2/2
- **Files touched:** 18 (1 créé, 17 modifiés dont 7 l10n générés)

## Accomplishments
- `ArchetypePredicates` (financial_core L1) : `canEstimateLppByEmployment` + `canEstimateLppByCivilStatus` + `isIndependantSansLpp`, exportés via le barrel `financial_core.dart`
- Re-câblage des deux moteurs sur le MÊME prédicat : `minimal_profile_service.dart:67-83` et `coach_profile.dart:2874-2913` — `grep -c "ArchetypePredicates"` ≥ 1 dans chacun
- Gate divorcé : nouvelle branche AVANT `_estimateLppAvoir` ; divorcé sans valeur réelle → `avoirLppTotal=null` + `lppEstimationBlocked=true`
- `PrevoyanceProfile.lppEstimationBlocked` (champ + copyWith/fromJson/toJson/==/hashCode)
- Clé ARB `lppEstimationBlockedRealValueRequired` ×6 langues (FR « Valeur réelle requise — scanne ton certificat LPP », sans terme banni) + `flutter gen-l10n`
- Tests de parité : 2 nouveaux groupes (« Gates LPP » 3 cas + « Gate divorce » 4 cas) → 33/33 verts

## Task Commits

1. **Task 1: ArchetypePredicates partagé + enforcement dans les deux moteurs**
   - `d331b07f1` (test, RED) — groupe « Gates LPP », test rouge : coach attribuait 76213 CHF de LPP fantôme à un indépendant
   - `a2b15b16a` (feat, GREEN) — ArchetypePredicates + re-câblage des deux moteurs ; parité 29/29, analyze lib clean
2. **Task 2: Gate divorcé — estimation LPP interdite + fallback scan**
   - `1a15f3768` (test, RED) — groupe « Gate divorce », test rouge : `lppEstimationBlocked` non défini
   - `c1581d227` (feat, GREEN) — gate divorcé + champ lppEstimationBlocked + ARB ×6 + gen-l10n ; parité 33/33, services 5851/5851, models 277/277

_Le SUMMARY + la mise à jour VALIDATION.md sont committés séparément (docs commit)._

## Files Created/Modified
- `archetype_predicates.dart` (créé) — prédicats d'archétype L1 : `canEstimateLppByEmployment` (interdit l'estimation pour un indépendant), `canEstimateLppByCivilStatus` (false pour divorcé), `isIndependantSansLpp`
- `financial_core.dart` — export du nouveau module dans le barrel
- `minimal_profile_service.dart` — gate LPP=0 routé via `ArchetypePredicates.canEstimateLppByEmployment` (même comportement qu'avant pour salarié/sans-emploi, indépendant toujours 0)
- `coach_profile.dart` — import du prédicat ; branche d'estimation re-câblée sur `canEstimateLppByEmployment` (fin du gate `!hasPensionFund`) ; gate divorcé via `canEstimateLppByCivilStatus` ; champ `PrevoyanceProfile.lppEstimationBlocked` ajouté partout
- `app_*.arb` (6) + `app_localizations*.dart` (7 générés) — clé `lppEstimationBlockedRealValueRequired`
- `financial_parity_test.dart` — groupes « Gates LPP » et « Gate divorce »

## Decisions Made
- **Gate par emploi, pas par question caisse.** `independent_no_lpp-3` était une divergence entre `employmentStatus=='independant'` (minimal) et `!hasPensionFund` (coach). Le prédicat partagé `canEstimateLppByEmployment` interdit l'estimation pour TOUT indépendant — un indépendant qui coche « oui » à la caisse ne reçoit plus un avoir estimé (seule une valeur réelle compte). Les deux moteurs renvoient le même verdict, testé au centime.
- **Divorcé : null + flag, pas 0.** Pour `cadre_divorce_hypo-1`, mettre l'avoir à 0 aurait laissé penser « pas de LPP ». On laisse `avoirLppTotal=null` (indéterminé) et on flagge `lppEstimationBlocked=true` pour que l'UI affiche « valeur réelle requise » (plan 11), pas un nombre estimé faux.
- **Confiance dégradée sans nouveau code.** `avoirLppTotal=null` fait tomber le `ConfidenceScorer` existant dans sa branche « avoir LPP non renseigné » (perte des 18 pts de complétude LPP), ce qui dégrade automatiquement la confiance d'un divorcé vs un marié estimé — prouvé par un test comparatif (Karpathy #2 : pas d'abstraction superflue).

## Deviations from Plan

None — plan exécuté tel qu'écrit. Le gate divorcé a été implémenté côté coach_profile uniquement (le chemin minimal_profile équivalent n'expose pas de paramètre `civilStatus` et son call-site `coach_profile_provider.dart:1223` ne passe que age/salaire/canton — il ne produit donc jamais d'avoir divorcé à fausser). La vérité d'archétype divorcé transite par `CoachProfile.fromWizardAnswers` (q_civil_status, peuplé au plan 06), qui est le moteur autoritaire pour cette dimension. Aucun élargissement de signature non requis (Karpathy #2/#3).

## Known Stubs

**`lppEstimationBlocked` est câblé côté données mais son consommateur UI est le plan 11 (intentionnel).** Le flag + la clé ARB `lppEstimationBlockedRealValueRequired` sont prêts ; l'écran hero qui les affiche (états connu/estimé/inconnu) est explicitement hors scope de ce plan (« NE PAS construire d'écran ici — l'affichage hero = plan 11 », action Task 2). Ce n'est pas un stub bloquant : la correction du gate (ne plus afficher 416k à un divorcé) est complète au niveau du moteur ; l'amélioration de présentation est livrée par le plan 11.

## Verification Evidence (0-TRUST)

```
Evidence : flutter test test/services/financial_parity_test.dart → "00:00 +33: All tests passed!"
Evidence : flutter analyze lib → "No issues found! (ran in 13.2s)"
Evidence : flutter test test/services/ → "01:03 +5851: All tests passed!"
Evidence : flutter test test/models/ → "00:01 +277: All tests passed!"
Evidence : grep -c "ArchetypePredicates" coach_profile.dart → 1 ; minimal_profile_service.dart → 1
Evidence : tools/checks/arb_parity.py → "OK — 6 locale(s) parity (reference=fr, 6903 keys each)"
Evidence : tools/checks/banned_terms_arb.py → "OK — 6 locale(s) clean"
Evidence : accent_lint_fr.py (scope fichiers touchés) → 0 violation sur app_fr.arb / coach_profile.dart / archetype_predicates.dart (les 283 violations globales sont pré-existantes dans services/backend/mortgage et tools/simulator, hors scope)
Evidence : RED→GREEN documenté — d331b07f1 (RED coach=76213) → a2b15b16a (GREEN coach=0) ; 1a15f3768 (RED lppEstimationBlocked indéfini) → c1581d227 (GREEN flag câblé)
Caveat   : end-to-end UNKNOWN — pas de walkthrough sim ; tests verts ≠ feature working (§9.2). Device-proof déféré à l'orchestrateur (build iOS impossible depuis worktree .nosync isolé, comme W1 plan 05 / W2 plan 06).
```

## Device-Proof Status

**DEFERRED-TO-ORCHESTRATOR.** Comme les W1/W2 précédents (`d755c06af`, plan 06), un build iOS complet depuis ce worktree `.nosync` isolé n'est pas réalisable sans casser la provenance/codesign macOS. Le device-proof (sim : profil divorcé → plus de 416k, indépendant déclarant une caisse → LPP=0) tourne contre la branche d'intégration mergée. Per 0-TRUST §9 : aucune revendication « works »/« ready » — preuve déterministe = tests verts uniquement.

## Next Phase Readiness
- `independent_no_lpp-3` et `cadre_divorce_hypo-1` fermés au niveau moteur, avec oracle re-run cité (RED→GREEN).
- Plan 08 (gates FATCA/frontalier) : `ArchetypePredicates` est le point d'extension naturel pour de futurs gates d'archétype.
- Plan 11 (hero confiance) : `PrevoyanceProfile.lppEstimationBlocked` + `lppEstimationBlockedRealValueRequired` sont prêts à être consommés pour l'état « valeur réelle requise ».

## Self-Check: PASSED

- Created file exists: `apps/mobile/lib/services/financial_core/archetype_predicates.dart`
- Commits exist: `d331b07f1`, `a2b15b16a`, `1a15f3768`, `c1581d227`
- SUMMARY exists: this file.

---
*Phase: mint-illogism-fixes*
*Completed: 2026-06-11*
