---
phase: mint-illogism-fixes
plan: 16
subsystem: ui
tags: [retirement-dashboard, coach-profile-provider, matrix-d7, matrix-d8, empty-state, cta, i18n, parity, go-router]

# Dependency graph
requires:
  - phase: mint-illogism-fixes-11
    provides: source de confiance unique (EnhancedConfidence.combined) + hero gate 3 états — le dashboard /retraite réutilise la même source de profil, pas un nouveau moteur
provides:
  - "RetirementDashboardScreen : l'état vide onboarding (« 4 infos suffisent ») ne s'affiche QUE si le profil est réellement vide (!CoachProfileProvider.hasProfile) — fin de la contradiction D7 avec /home qui lit le même provider"
  - "_buildProjectionUnavailable : nouvel état récupérable (retry + Mes données) quand un profil hydraté n'a pas pu produire de projection — plus jamais l'onboarding trompeur"
  - "CTA d'état vide « Commencer — 2 min » re-câblé vers /onb (OnboardingShellScreen — âge/canton/revenu) au lieu de /coach/chat mort (D8) ; Key('state_c_start_cta')"
  - "2 clés ARB ×6 langues (dashboardProjectionUnavailableTitle/Body)"
affects: [retraite-dashboard, coach-home, matrix-d7, matrix-d8, onboarding-shell]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Prédicat d'état vide à 3 branches : !hasProfile → onboarding (State C) ; hasProfile && _projection==null → état récupérable (retry) ; sinon → dashboard. Sépare « pas de données » (onboarding légitime) de « calcul échoué » (jamais l'onboarding trompeur)."
    - "Le dashboard /retraite consomme la MÊME source que /home (CoachProfileProvider.hasProfile/profile) — pas de second moteur de profil ; la cohérence inter-surfaces est garantie par la source unique, pas par une re-synchronisation."
    - "CTA d'état vide pointe vers un parcours qui pose réellement des questions (route GoRouter /onb avec champs de saisie testés), jamais vers une surface conversationnelle sans formulaire."

key-files:
  created:
    - apps/mobile/test/screens/retirement_dashboard_profile_test.dart
  modified:
    - apps/mobile/lib/screens/coach/retirement_dashboard_screen.dart
    - apps/mobile/lib/l10n/app_*.arb (6 langues) + app_localizations*.dart (7 générés)

key-decisions:
  - "D7 racine = prédicat d'état vide, PAS divergence de source. Le dashboard lit déjà le même CoachProfileProvider que /home (retirement_dashboard_screen.dart:113, 372). La contradiction « 43'691 Avoir LPP » (/home) vs « 4 infos suffisent » (/retraite) vient du prédicat `(!hasProfile || _projection == null)` (ligne 374) qui confond profil-vide et projection-échouée."
  - "On NE ment plus quand la projection échoue : profil hydraté + _projection==null → état récupérable (_buildProjectionUnavailable, retry + Mes données), pas l'onboarding « 4 infos suffisent » qui contredit /home."
  - "Cible CTA = /onb (OnboardingShellScreen, steps age/canton/revenue — les scènes du plan 06), choisie car les routes /onboarding/* sont des redirect-shims morts vers /coach/chat (app.dart:1575-1633). /onb est le seul parcours réel qui pose des questions avec champs."
  - "Réutilisation ARB (Karpathy #2) : l'état récupérable réutilise commonRetry (« Réessayer ») + dashboardMyData (« Mes données ») ; seuls le titre et le corps sont de nouvelles clés (×6)."

patterns-established:
  - "État vide d'un écran de projection : l'onboarding ne s'affiche que sur profil réellement absent ; un calcul indisponible sur profil présent obtient un état récupérable distinct, jamais l'onboarding."

requirements-completed: [MATRIX-D7, MATRIX-D8]

# Metrics
metrics:
  duration: ~22 min
  completed: 2026-06-11
  tasks: 2
  commits: 2
  files_created: 1
  files_modified: 14
---

# Phase mint-illogism-fixes Plan 16: W5 — Vérité du tableau retraite (D7 + D8) Summary

**One-liner :** `/retraite` ne se déclare plus vide (« 4 infos suffisent ») quand `/home` montre déjà les données du même `CoachProfileProvider` dans la même minute — l'état vide onboarding ne s'affiche QUE si le profil est réellement absent (`!hasProfile`), un profil hydraté dont la projection a échoué obtient un état récupérable (`_buildProjectionUnavailable`, retry + Mes données) au lieu de l'onboarding trompeur (D7) ; et le CTA mort « Commencer — 2 min » → `/coach/chat` (home coach sans formulaire) est re-câblé vers `/onb` (OnboardingShellScreen — âge/canton/revenu, les scènes du plan 06 qui posent réellement des questions) (D8).

## Performance

- **Duration:** ~22 min
- **Completed:** 2026-06-11
- **Tasks:** 2/2
- **Files touched:** 15 (1 créé, 14 modifiés dont 7 l10n générés)

## Accomplishments

### Task 1 — Diagnostic D7/D8 (aucune modification de code)
- **D7 racine citée file:line.** Le dashboard lit DÉJÀ le même provider que /home :
  - `retirement_dashboard_screen.dart:113` (`context.watch<CoachProfileProvider>()` dans `didChangeDependencies`) et `:372` (même watch dans `build`).
  - Le prédicat d'état vide est `(!provider.hasProfile || _projection == null)` (`:374`). `hasProfile` = `_profile != null` (`coach_profile_provider.dart:122`) — **identique à la source de /home**.
  - La contradiction vient du **deuxième terme** : `ForecasterService.project()` est appelé dans `didChangeDependencies` (`:147`) sous `try/catch` ; si l'estimateur lève, le catch met `_projection = null` (`:159`). Un profil hydraté (avoir LPP que /home rend via le même provider) + `_projection==null` retombe alors en State C → `_buildOnboardingHero` affiche `dashboardQuickStartBody` = « 4 infos suffisent… » (`app_fr.arb:669`).
  - **Conclusion : pas deux moteurs/champs distincts** — un seul provider, mais un prédicat d'état vide qui conflate « pas de profil » et « projection échouée ».
- **D8 racine citée file:line.** Le CTA d'état vide `_buildOnboardingHero` faisait `onPressed: () => context.go('/coach/chat')` (`:946`) → home coach, aucun formulaire. Cible vivante identifiée : `/onb` → `OnboardingShellScreen` (`app.dart:354-356`) dont la step machine pose `age` / `canton` / `revenue` (`onboarding_shell_screen.dart:117-122`) — les scènes du plan 06. Les routes `/onboarding/*` sont au contraire des redirect-shims morts vers `/coach/chat` (`app.dart:1575-1633`) → écartées.

### Task 2 — Alignement source + re-câblage CTA (D7 + D8 fermés) [TDD]
- **D7 fix** : le prédicat de `build` passe de 2 à 3 branches (`retirement_dashboard_screen.dart`) :
  - `!provider.hasProfile` → `_buildStateC()` (onboarding légitime).
  - `_projection == null` (profil présent) → **nouveau** `_buildProjectionUnavailable()` : titre/corps honnêtes (« tes données sont là, mais nous n'avons pas pu construire la projection »), CTA `Réessayer` (`Key('projection_retry_cta')`, recompute via `_retryProjection`) + `Mes données` (`Key('projection_review_cta')` → `/profile/bilan`). Plus jamais « 4 infos suffisent » quand /home montre les données.
  - sinon → `_buildDashboard()`.
- **D8 fix** : CTA d'état vide `Key('state_c_start_cta')` → `context.go('/onb')` (au lieu de `/coach/chat`).
- **`_retryProjection`** : ré-exécute le même chemin que `didChangeDependencies` (FinancialFitnessService + ForecasterService + ConfidenceScorer + curation) sous `setState` — source unique, pas de duplication de logique.
- **2 clés ARB ×6 langues** : `dashboardProjectionUnavailableTitle`, `dashboardProjectionUnavailableBody` + `flutter gen-l10n`. Réutilise `commonRetry` + `dashboardMyData` (Karpathy #2).
- **Tests** : `retirement_dashboard_profile_test.dart` (3 cas) — profil hydraté (avoir LPP) → PAS d'état vide ; profil réellement vide → état vide + CTA ; tap CTA état vide → route `/onb` avec champ de saisie (`TextField`), plus jamais `/coach/chat` mort. Le widget cible du CTA contient un champ de saisie (testé, threat T-ILF-16-02).

## Task Commits

1. **Task 2 — Aligner la source + re-câbler le CTA (D7 + D8)** [TDD]
   - `0216687b7` (test, RED) — 3 cas D7/D8 ; échoue avant impl : `Key('state_c_start_cta')` absent + CTA pointe `/coach/chat`
   - `25f392057` (feat, GREEN) — prédicat 3 branches + `_buildProjectionUnavailable` + `_retryProjection` + CTA `/onb` + `Key('state_c_start_cta')` + 2 clés ARB ×6 + gen-l10n

_Task 1 = diagnostic pur (aucune modification de fichier) → pas de commit dédié ; documenté ci-dessus + dans VALIDATION.md._
_Le SUMMARY + la mise à jour VALIDATION.md sont committés séparément (docs commit)._

## Files Created/Modified
- `retirement_dashboard_profile_test.dart` (créé) — 3 cas : D7 source unique (hydraté → pas d'état vide ; vide → état vide) + D8 CTA vivant (tap → /onb avec champ de saisie).
- `retirement_dashboard_screen.dart` — prédicat `build` à 3 branches ; `_buildProjectionUnavailable` + `_retryProjection` ; CTA d'état vide `Key('state_c_start_cta')` → `/onb`.
- `app_*.arb` (6) + `app_localizations*.dart` (7 générés) — 2 nouvelles clés `dashboardProjectionUnavailableTitle/Body`.

## Decisions Made
- **D7 = prédicat, pas double source.** La matrice parlait de « deux moteurs/champs ». La lecture du code montre une source unique (`CoachProfileProvider`) déjà partagée avec /home ; la vraie cause est le prédicat d'état vide qui conflate profil-vide et projection-échouée. Le fix cible le prédicat réel observable, pas un second moteur fantôme.
- **État récupérable plutôt que masquage.** Au lieu de forcer le dashboard même sans projection (risque de crash) ou de garder l'onboarding trompeur, un état dédié honnête (retry + revue des données) respecte le 0-TRUST : on n'affirme pas une donnée qu'on n'a pas pu calculer.
- **/onb retenu sur /onboarding/*.** Les `/onboarding/*` sont des shims morts (redirect → /coach/chat) ; `/onb` est le seul parcours réel avec champs (OnboardingShellScreen, plan 06).
- **Réutilisation ARB.** `commonRetry` + `dashboardMyData` réutilisés ; seuls titre + corps de l'état récupérable sont nouveaux (Karpathy #2).

## Deviations from Plan

**1. [Rule 2 - Missing Critical] État récupérable `_buildProjectionUnavailable` ajouté (non explicitement spécifié).**
- **Found during:** Task 2.
- **Issue:** Corriger D7 en n'affichant l'onboarding que sur `!hasProfile` laisse un trou : un profil hydraté dont la projection échoue (`_projection==null`) n'avait plus de branche de rendu honnête (l'ancien code l'envoyait en State C trompeur). Sans nouvelle branche, le `build` aurait crashé sur `_buildDashboard()` (`_projection!`).
- **Fix:** Branche dédiée `_buildProjectionUnavailable` (retry + revue), au lieu de retomber sur l'onboarding mensonger ou de déréférencer un projection null.
- **Files modified:** `retirement_dashboard_screen.dart`, `app_*.arb` ×6.
- **Verification:** `retirement_dashboard_profile_test.dart` 3/3 ; analyze clean.
- **Committed in:** `25f392057` (commit GREEN Task 2).

---

**Total deviations:** 1 auto-fixed (Rule 2 — correctness, évite un crash sur projection null tout en honorant le 0-TRUST).
**Impact on plan:** L'ajout est nécessaire pour fermer D7 sans introduire un crash ni un nouveau mensonge. Aucun scope creep — strictement la correction du prédicat d'état vide.

## Issues Encountered
- **RenderFlex overflow de `RetirementHeroZone` en environnement de test** (limitation pré-existante notée dans `retirement_dashboard_test.dart:82-83`). Le test D7 « profil hydraté » draine l'exception de layout via `tester.takeException()` — l'overflow PROUVE justement que le dashboard (pas State C) a été rendu, ce qui est l'assertion D7. Pas un bug de ce plan.

## Threat Surface
- T-ILF-16-01 (intégrité inter-surfaces) : mitigé — source profil unique (`CoachProfileProvider`) + test (profil hydraté → pas d'état vide).
- T-ILF-16-02 (CTA mort / DoS d'entrée) : mitigé — la cible de route `/onb` est testée comme contenant un champ de saisie (`TextField`).

## Verification Evidence (0-TRUST)

```
Evidence : flutter test test/screens/retirement_dashboard_profile_test.dart → "00:00 +3: All tests passed!"
Evidence : flutter test (retirement_dashboard_test + retirement_dashboard_profile_test) → "00:00 +8: All tests passed!"
Evidence : flutter test test/screens/coach_screens_additional_smoke_test.dart → "00:00 +15: All tests passed!" (non-régression dashboard route)
Evidence : flutter analyze (retirement_dashboard_screen.dart + retirement_dashboard_profile_test.dart) → "No issues found! (ran in 1.1s)"
Evidence : tools/checks/arb_parity.py → "OK — 6 locale(s) parity (reference=fr, 6919 keys each)." (exit 0)
Evidence : tools/checks/banned_terms_arb.py → "OK — 6 locale(s) clean (no positive LSFin banned-term uses)." (exit 0)
Evidence : tools/checks/accent_lint_fr.py --file app_fr.arb → ACCENT_EXIT=0 (aucune des 2 nouvelles clés flaggée)
Evidence : lefthook pre-commit GREEN — prefer-mint-cta + arb-parity-gate + banned-terms-arb-gate tous ✔️ sur le commit 25f392057
Evidence : RED→GREEN documenté — 0216687b7 (RED, Key('state_c_start_cta') absent → +0 -3) → 25f392057 (GREEN → +3)
Evidence : citations racine D7 — retirement_dashboard_screen.dart:113,372 (même CoachProfileProvider que /home) ; :374 (prédicat conflatant) ; :147,159 (project() sous try/catch → _projection=null) ; coach_profile_provider.dart:122 (hasProfile) ; app_fr.arb:669 (« 4 infos suffisent »)
Evidence : citations racine D8 — retirement_dashboard_screen.dart:946 (ancien context.go('/coach/chat')) ; app.dart:354-356 (/onb → OnboardingShellScreen) ; onboarding_shell_screen.dart:117-122 (steps age/canton/revenue)
Caveat   : end-to-end UNKNOWN — pas de walkthrough sim ; tests verts ≠ feature working (§9.2). Device-proof D7/D8 (séquence /home puis /retraite dans la même minute → cohérence ; tap CTA → questions visibles ; captures `.planning/_walker/illogism-fixes/w5/`) + panel design 4-personnes sur l'écran modifié DÉFÉRÉS à l'orchestrateur (build iOS impossible depuis worktree .nosync isolé, comme W1-W4 plans 05/06/07/08/11/12/13/14). STATE.md / ROADMAP.md non modifiés (propriété orchestrateur).
```

## Known Stubs

Aucun. L'état récupérable `_buildProjectionUnavailable` est entièrement câblé (retry recompute la projection ; « Mes données » route vers `/profile/bilan`). Le CTA `/onb` mène à un parcours réel (OnboardingShellScreen, testé comme contenant un champ de saisie).

## Device-Proof Status

**DEFERRED-TO-ORCHESTRATOR.** Comme W1-W4 (plans 05/06/07/08/11/12/13/14), un build iOS complet depuis ce contexte `.nosync` n'est pas réalisable sans casser la provenance/codesign macOS. À exécuter par l'orchestrateur au moment du device-proof :
- **D7** : seed un profil hydraté → /home affiche « 43'691 Avoir LPP » → /retraite dans la même minute → cohérent (PAS « 4 infos suffisent »).
- **D8** : profil vide → /retraite → tap « Commencer — 2 min » → écran /onb qui POSE des questions (âge/canton/revenu visibles).
- **Panel design 4-personnes** sur l'écran modifié (état récupérable + CTA re-câblé).
- Captures `.planning/_walker/illogism-fixes/w5/`.

Per 0-TRUST §9 : aucune revendication « works »/« ready » — preuve déterministe = tests verts + lints uniquement.

## Next Phase Readiness
- D7, D8 fermés au niveau code/test avec oracle re-run cité (RED→GREEN + citations file:line des deux chemins de lecture et de la cible CTA).
- Le pattern « état vide onboarding seulement si profil réellement absent » est réutilisable sur les autres surfaces de projection (premier-eclairage, mon-argent) si une divergence similaire émerge.
- Plan 17 (W5 — D9 hypothèses what-if + D11 i18n hardcode + clôture phase) est le suivant naturel.

## Self-Check: PASSED

- Created file exists: `apps/mobile/test/screens/retirement_dashboard_profile_test.dart`
- Created file exists: this SUMMARY.
- Commits exist: `0216687b7` (RED), `25f392057` (GREEN).

---
*Phase: mint-illogism-fixes*
*Completed: 2026-06-11*
