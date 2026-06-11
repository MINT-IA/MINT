---
phase: mint-illogism-fixes
plan: 06
subsystem: ui
tags: [flutter, onboarding, archetype, provider, i18n, avs, civil-status, employment]

# Dependency graph
requires:
  - phase: mint-illogism-fixes-05
    provides: W1 calc-engine fixes (LPP/AVS/3a) that consume archetype truth
provides:
  - 3 onboarding archetype-truth questions (statut d'emploi, état civil incl. divorce, lacunes AVS)
  - q_employment_status / q_civil_status / q_avs_lacunes_status (+ q_avs_arrival_year / q_avs_years_abroad) now populated by the /onb flow
  - independant / sans_activite no longer auto-presumes a 2nd pillar (NEVER #7)
affects: [mint-illogism-fixes-07, mint-illogism-fixes-08, coach-profile-archetype-resolution]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Archetype-signal onboarding step: capture on OnboardingProvider (setX) + re-emit at T8 flush; in-flow CoachProfileProvider.mergeAnswers write mirrors the us-tax-person gate, never the dossier flush"
    - "Scene value constants pinned to the exact parser strings, guarded by a compile-time assert on the canonical enum (CoachCivilStatus)"
    - "Two-step scene (status → numeric follow-up) with digits-only + range-validated input for AVS arrival year / years abroad"

key-files:
  created:
    - apps/mobile/lib/screens/onboarding/mvp_wedge/scenes/mint_scene_lacunes_avs.dart
    - apps/mobile/lib/screens/onboarding/mvp_wedge/scenes/mint_scene_statut_emploi.dart
    - apps/mobile/lib/screens/onboarding/mvp_wedge/scenes/mint_scene_etat_civil.dart
    - apps/mobile/test/screens/onboarding/mvp_wedge/mint_scene_lacunes_avs_test.dart
    - apps/mobile/test/screens/onboarding/mvp_wedge/onboarding_archetype_flow_test.dart
    - apps/mobile/test/screens/onboarding/mvp_wedge/mint_scene_statut_emploi_test.dart
    - apps/mobile/test/screens/onboarding/mvp_wedge/mint_scene_etat_civil_test.dart
  modified:
    - apps/mobile/lib/screens/onboarding/mvp_wedge/onboarding_provider.dart
    - apps/mobile/lib/screens/onboarding/mvp_wedge/onboarding_shell_screen.dart
    - apps/mobile/lib/models/coach_profile.dart
    - apps/mobile/lib/l10n/app_*.arb (6 langues) + generated app_localizations*.dart
    - apps/mobile/test/screens/onboarding/mvp_wedge_storyboard_test.dart

key-decisions:
  - "W2 scenes capture on OnboardingProvider AND mirror an in-flow CoachProfileProvider write (like the us-tax-person gate); the T8 flush stays the single authoritative dossier write"
  - "Inserted employment → civilStatus → avsLacunes between nationality and age (archetype signals before financial-data collection); enum insertion is ordinal-safe (advance() walks values via indexOf)"
  - "AVS lacunes is a two-step scene: status then numeric follow-up only when the status needs a year/count (arrived_late / lived_abroad)"

patterns-established:
  - "Archetype onboarding step: thin shell wrapper → MintScene* → setX on OnboardingProvider → advance(); no DossierStrip line (PII invisible post-answer)"
  - "Parser-pinned scene constants + compile-time enum assert to prevent silent string drift"

requirements-completed: [MATRIX-D1]

# Metrics
duration: ~47min (Task 2 resume segment; Task 1 from prior interrupted session)
completed: 2026-06-11
---

# Phase mint-illogism-fixes Plan 06: W2 Onboarding Archetype Questions Summary

**L'onboarding /onb établit désormais la vérité d'archétype — statut d'emploi (salarié/indépendant/sans activité), état civil (incl. divorcé) et lacunes AVS (années hors de Suisse) — peuplant les clés wizard EXISTANTES lues par coach_profile.dart sans nouveau champ de schéma, fermant la racine D1 des ~10 ILLOGICAL_FOR_ARCHETYPE.**

## Performance

- **Duration:** Task 2 resume segment ~47 min (Task 1 executed in a prior session interrupted by a quota cut)
- **Completed:** 2026-06-11T15:48Z
- **Tasks:** 2/2
- **Files touched (cumulative across both tasks):** 25 dart/arb files

## Accomplishments
- 3 scènes archétype dans le wedge : `MintSceneStatutEmploi`, `MintSceneEtatCivil` (incl. divorce), `MintSceneLacunesAvs` (two-step status → année/nombre)
- Câblage shell + provider : étapes `employment → civilStatus → avsLacunes` insérées entre `nationality` et `age` ; le flush T8 ré-émet les clés q_* capturées (store-replacement-safe)
- `_parseEmploymentStatus` corrigé : `sans_activite` n'est plus coercé en `salarie` ; indépendant/sans-activité ne présume plus de LPP (NEVER #7)
- 8 clés ARB lacunes AVS × 6 langues + `flutter gen-l10n` régénéré (accents FR corrects, zéro terme banni)
- Tests : 9 widget (statut + état civil, Task 1) + 5 widget (lacunes AVS) + 4 intégration (ordre du flux + ré-émission au flush) ; storyboard mis à jour → 39/39 verts dans `test/screens/onboarding/`

## Task Commits

1. **Task 1: Scènes statut d'emploi + état civil** — `6a8564bdc` (feat) — MintSceneStatutEmploi + MintSceneEtatCivil + `_parseEmploymentStatus` fix + 9 widget tests
2. **Task 2: Scène lacunes AVS + intégration au flux** — `3482014f4` (feat) — MintSceneLacunesAvs + wiring shell/provider + 5 widget + 4 intégration tests + storyboard fix

_Plan metadata (SUMMARY) committed separately as the docs commit._

## Files Created/Modified
- `scenes/mint_scene_lacunes_avs.dart` — scène lacunes AVS, two-step, écrit q_avs_lacunes_status (+ q_avs_arrival_year / q_avs_years_abroad)
- `scenes/mint_scene_statut_emploi.dart` — scène statut d'emploi (salarie/independant/sans_activite)
- `scenes/mint_scene_etat_civil.dart` — scène état civil (CoachCivilStatus incl. divorce)
- `onboarding_provider.dart` — enum steps employment/civilStatus/avsLacunes, setters de capture, flush ré-émet les q_* + LPP conditionnée au salariat
- `onboarding_shell_screen.dart` — wrappers `_EmploymentStep` / `_CivilStatusStep` / `_AvsLacunesStep` enregistrés dans le flux
- `coach_profile.dart` — `_parseEmploymentStatus` reconnaît `sans_activite`
- `app_*.arb` (6) + `app_localizations*.dart` (7 générés) — clés employment/civil/avs
- `mvp_wedge_storyboard_test.dart` — helper `_commonEntry` traverse les 3 nouvelles étapes ; whitelist du fake étendue aux in-flow gate keys
- nouveaux tests : `mint_scene_lacunes_avs_test.dart`, `onboarding_archetype_flow_test.dart`

## Decisions Made
- Les 3 scènes sont des signaux d'archétype traités comme l'étape us-tax-person : écriture in-flow `CoachProfileProvider.mergeAnswers` (mirroir) + capture `OnboardingProvider.setX` ré-émise au flush T8. Le flush reste l'unique écriture autoritaire du dossier.
- Insertion mid-enum (employment/civilStatus/avsLacunes) entre nationality et age : ordinal-safe car `advance()` parcourt `OnboardingStep.values` via `indexOf` (aucun `.index` persisté ni en analytics).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] `flutter gen-l10n` non exécuté → S class sans les clés lacunes AVS**
- **Found during:** Task 2 (reprise) — le code des scènes référençait `l.onboardingAvs*` mais les ARB n'avaient pas été régénérés, donc `flutter analyze`/compilation auraient échoué.
- **Fix:** `cd apps/mobile && flutter gen-l10n` → 7 fichiers `app_localizations*.dart` régénérés avec les 8 accesseurs.
- **Verification:** `grep onboardingAvsPrompt app_localizations.dart` présent ; `flutter analyze` sur les fichiers touchés → No issues found.
- **Committed in:** `3482014f4`

**2. [Rule 1 - Bug] Régression `mvp_wedge_storyboard_test.dart` (12 tests rouges)**
- **Found during:** Task 2 — l'insertion des 3 étapes a cassé le helper `_commonEntry` (attendait l'âge directement après nationality) ET les assertions `mergedCalls.single` (les écritures in-flow des scènes ajoutaient des entrées au merge-log du fake).
- **Fix:** (a) `_commonEntry` traverse maintenant statut → état civil → lacunes (baseline swissNative : salarié/marié/no_gaps) ; (b) la whitelist du fake (déjà appliquée à `q_us_tax_person`) étendue aux clés in-flow archétype `q_employment_status` / `q_civil_status` / `q_avs_lacunes_status` — comme la gate us-tax, ce ne sont pas le flush dossier T8.
- **Verification:** `flutter test test/screens/onboarding/` → 39/39 verts.
- **Committed in:** `3482014f4`

---

**Total deviations:** 2 auto-fixed (1 blocking, 1 bug)
**Impact on plan:** Les deux corrections étaient nécessaires à la justesse (compilation + non-régression du storyboard verrouillé). Pas de scope creep ; aucune nouvelle abstraction.

## Design Panel (4-personnes) — Verdicts

Revue structurée des 3 scènes (audit mécanique cité, pas un claim « validated ») :

- **UX** — PASS. Divulgation progressive (AVS : statut puis follow-up numérique uniquement si nécessaire). Cadrage générique « ta situation professionnelle/familiale », « hors de Suisse » — pas de framing retraite (NEVER #4). Position-hints « 2 / 4 » sur chaque option.
- **a11y (WCAG)** — PASS. `Semantics(header: true)` sur les prompts, `inMutuallyExclusiveGroup` (radio group), labels + hints par bouton, cibles tactiles 48–52 px, `autofocus` + `onTapOutside`-unfocus sur le champ numérique. Audit : statut/civil = 3 blocs Semantics, AVS = 5 (2 headers).
- **Adversarial / sécurité PII** — PASS. Aucune ligne DossierStrip pour état civil/emploi (invisibles post-réponse) ; écriture uniquement vers le store chiffré ; grep-gate `q_civil_status|q_employment_status` ∩ `log|analytic|sentry` → 0 (le seul match est le commentaire « split **log**ic », faux positif). Input numérique : digits-only + LengthLimiting + validation de plage.
- **Engineering / wiring** — PASS. Constantes de scène épinglées aux valeurs EXACTES du parser (coach_profile.dart:2668/2702/2802) ; `assert(CoachCivilStatus.values.length == 5)` compile-time guard ; flush ré-émet (store-replacement-safe) ; LPP non présumée pour indépendant/sans-activité (NEVER #7).

Aucun fix critique bloquant identifié ; le risque overflow petit-écran de `_buildStatusChoice` (Spacer sans scroll) est identique au pattern etat_civil existant (5 options) déjà en prod — hors scope (Karpathy #3).

## Issues Encountered
- Test d'intégration : `completeAndFlushToProfile` vérifie `coachProvider.hasProfile` après merge ; le fake initial n'overridait pas `hasProfile`/`updateFromAnswers` → `StateError: onboarding_profile_unavailable_after_merge`. Résolu en mirrorant la base storyboard-fake (override `hasProfile` + `updateFromAnswers`).

## Verification Evidence (0-TRUST)

```
Evidence : flutter analyze (5 fichiers touchés) → "No issues found! (ran in 3.3s)"
Evidence : flutter analyze (storyboard test + scenes test dir) → "No issues found! (ran in 2.1s)"
Evidence : flutter test test/screens/onboarding/ → "00:03 +39: All tests passed!"
Evidence : flutter test mint_scene_lacunes_avs_test.dart → 5/5 ; onboarding_archetype_flow_test.dart → 4/4
Evidence : accent_lint_fr.py --file <touched> → empty (0 violations) sur ARB FR + scène + tests
Evidence : grep "Text('" mint_scene_lacunes_avs.dart → 0 (i18n, NEVER #1)
Evidence : grep "Color(0x" sur les 3 scènes → 0 (MintColors only, NEVER #2)
Evidence : banned-terms scan manuel sur les 8 strings FR → clean (NEVER #5)
Caveat   : end-to-end UNKNOWN — walkthrough sim /onb + captures sous .planning/_walker/illogism-fixes/w2/ NON exécuté (tests verts ≠ feature working, §9.2).
```

## Device-Proof Status

**DEFERRED-TO-ORCHESTRATOR.** Le walkthrough sim /onb complet + captures `.planning/_walker/illogism-fixes/w2/` sont déférés à l'orchestrateur, comme le précédent W1 du plan 05 (`d755c06af`) : un build iOS complet depuis un worktree `.nosync` isolé n'est pas réalisable sans violer la doctrine de provenance/codesign macOS. Le device-proof tourne contre la branche d'intégration mergée. Per 0-TRUST §9 : je ne revendique pas « works »/« ready » — preuve déterministe = tests verts uniquement, end-to-end UNKNOWN.

## Next Phase Readiness
- D1 (vérité d'archétype) câblé côté capture + flush ; les plans 07-08 disposent de q_employment_status / q_civil_status / q_avs_lacunes_status en entrée.
- Blocker restant pour la clôture « D1 fermé avec device-proof » : le walkthrough sim (orchestrateur).

## Self-Check: PASSED

- Created files exist: mint_scene_lacunes_avs.dart, mint_scene_lacunes_avs_test.dart, onboarding_archetype_flow_test.dart, this SUMMARY.
- Commits exist: `6a8564bdc` (Task 1), `3482014f4` (Task 2).

---
*Phase: mint-illogism-fixes*
*Completed: 2026-06-11*
