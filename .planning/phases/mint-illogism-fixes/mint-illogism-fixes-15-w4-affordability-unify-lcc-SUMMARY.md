---
phase: mint-illogism-fixes
plan: 15
subsystem: mortgage / lucidity-L4
tags: [affordability, prefill, household-income, ASB, legal-citation, couple_acheteurs]
requires:
  - mint-illogism-fixes-05
provides:
  - "revenuBrutMenageFromProfile — source unique du revenu de ménage pour les deux routes d'AffordabilityScreen"
  - "resolveAffordabilityRevenu — résolution prefill coach vs profil convergente"
  - "Citation légale L4 mortgage-cap corrigée (Directives ASB / FINMA)"
affects:
  - apps/mobile/lib/screens/mortgage/affordability_screen.dart
  - services/backend/app/api/v1/endpoints/lucidity.py
tech-stack:
  added: []
  patterns:
    - "Délégation au getter canonique CoachProfile.revenuBrutAnnuelCouple (pas de duplication de calcul — NEVER #3)"
    - "Helper top-level testable sans plumbing widget (revenuBrutMenageFromProfile / resolveAffordabilityRevenu)"
key-files:
  created:
    - apps/mobile/test/screens/affordability_prefill_test.dart
  modified:
    - apps/mobile/lib/screens/mortgage/affordability_screen.dart
    - services/backend/app/api/v1/endpoints/lucidity.py
    - services/backend/tests/test_l4_invariant_endpoint.py
decisions:
  - "legal_article_ref = 'Directives ASB (FINMA)' (label aligné sur mortgage_service.dart + affordabilitySource ARB), pas la LCC qui exclut le crédit hypothécaire"
  - "Prefill coach partiel (mensuel) complété depuis le revenu du ménage du profil ; prefill complet (revenuBrut annuel) reste prioritaire"
metrics:
  duration: ~25 min
  completed: 2026-06-11
  tasks: 2
  files: 4
---

# Phase mint-illogism-fixes Plan 15: W4 — Affordability unifiée + citation LCC Summary

Unification du revenu de ménage prérempli sur `AffordabilityScreen` (les deux routes — profil et coach-prefill — produisent désormais le MÊME revenu via `revenuBrutAnnuelCouple`, fin du 1.02M vs 0.59M), plus correction de la citation légale fausse « LCC art. 28 » → « Directives ASB (FINMA) » dans l'endpoint L4 mortgage-cap.

## What Was Built

### Task 1 — Helper revenu de ménage unique pour les deux routes (commit `c15416ea4`)
- **TDD RED→GREEN** : `apps/mobile/test/screens/affordability_prefill_test.dart` (6 tests) écrit en premier, échec compilation (helpers absents) confirmé, puis implémentation.
- **`revenuBrutMenageFromProfile(CoachProfile)`** : source unique, délègue au getter canonique `CoachProfile.revenuBrutAnnuelCouple` (déjà existant, lib/models/coach_profile.dart:1912) qui somme utilisateur + conjoint avec chaque `nombreDeMois` propre et sans dérouler le conjoint. Respecte NEVER #3 (pas de duplication de calcul).
- **`resolveAffordabilityRevenu({prefill, profile})`** : règle de priorité — prefill complet (`revenuBrut` annuel explicite) prioritaire ; prefill partiel (`salaireBrut` mensuel seul) complété depuis le revenu du ménage du profil ; sinon revenu du ménage du profil ; sinon `null` (défaut écran conservé).
- **Route profil** (`_initializeFromProfile`, :64-67 avant) → consomme `revenuBrutMenageFromProfile`.
- **Route coach-prefill** (`_applyPrefill`, :115-121 avant) → consomme `resolveAffordabilityRevenu`. Le `salaireBrut * 13` codé en dur (qui déroulait le conjoint) est SUPPRIMÉ.
- **Contrôle négatif** : `mortgage_service.dart` NON touché (couple_acheteurs-5 = règle des 10% durs + règle du tiers, correcte et SOURCED).

### Task 2 — Citation légale L4 mortgage-cap corrigée (commit `649a3a6bd`, séparé)
- `services/backend/app/api/v1/endpoints/lucidity.py` : `legal_article_ref="LCC art. 28"` → `"Directives ASB (FINMA)"`. Le texte FR de condition, le docstring et l'en-tête de module sont mis à jour ; ajout d'une note expliquant que le plafond de charge 33% ne relève PAS de la loi sur le crédit à la consommation (qui exclut le crédit hypothécaire).
- Tests de contrat mis à jour (`test_l4_invariant_endpoint.py:45,47,65`) pour asserter la citation corrigée + un garde-fou `"LCC" not in condition_text_fr`.
- Commit séparé, message neutre (public-repo discipline).

## Verification Evidence (0-TRUST)

| Critère | Commande | Résultat |
|---|---|---|
| `*13` codé en dur supprimé | `grep -n "\* 13\|\*13" affordability_screen.dart` | `0 — clean` |
| Test prefill (oracle deux routes) | `flutter test test/screens/affordability_prefill_test.dart` | `+6 All tests passed!` (couple → 196800 par les deux routes) |
| Analyse statique | `flutter analyze lib/screens/mortgage/affordability_screen.dart test/screens/affordability_prefill_test.dart` | `No issues found!` |
| Non-régression prefill/writeback | `flutter test test/screens/calculator_prefill_writeback_test.dart` | `+19 All tests passed!` |
| Contrôle négatif couple_acheteurs-5 | `flutter test test/services/mortgage_service_test.dart` | `+34 All tests passed!` (fichier untouched) |
| Citation LCC retirée de l'endpoint | `grep -cn "LCC" lucidity.py` | `0` |
| Backend full suite | `cd services/backend && python3 -m pytest tests/ -q` | `7586 passed, 116 skipped, 4 xfailed` exit 0 |

Caveat : pas de run sim end-to-end (changement de logique de préremplissage testé déterministiquement RED→GREEN + analyze ; pas de surface visuelle nouvelle). « works » end-to-end device = UNKNOWN, non revendiqué.

## Oracle (couple_acheteurs-1, MATRIX-illogismes-2026-06-09:300-306)

- AVANT : route profil = 196'800 (salaire×12 + conjoint×12) → prixMaxRevenu ≈ 1'022'857 ; route coach-prefill = 106'600 (salaire×13, conjoint déroulé) → prixMaxRevenu ≈ 593'333 (−45.8%).
- APRÈS : les deux routes = 196'800 pour le couple matrice (8200×12 + 8200×12). Même personne, même écran, même réponse. couple_acheteurs-1 fermé.

## Design Panel (4-personnes, AVANT push — règle feedback_design_panel_before_push)

Diff appliqué à un changement de logique de préremplissage (aucun nouveau widget, aucune surface visuelle).
- **UX — PASS** : correction invisible-mais-juste ; le badge `SmartDefaultIndicator` « Depuis ton profil MINT » continue de s'afficher (`_prefilledFields.add('revenu_brut')` préservé) ; champ revenu reste éditable.
- **a11y — PASS** : aucun changement d'arbre widget, aucun `Semantics` retiré, champ `affordabilityGrossIncome` inchangé.
- **Adversarial — PASS** : `marie` sans conjoint → `revenuBrutAnnuelCouple` retombe sur le revenu utilisateur seul (doc P2-19, pas de revenu fantôme) ; prefill complet prioritaire ; pas de profil + pas de prefill → `null` (défaut conservé) ; `context.read` protégé par try/catch.
- **Engineering/wiring — PASS** : délègue au getter canonique (single source of truth, NEVER #3) ; pas de terme LSFin banni ; pas de string hardcodée user-facing (commentaires seulement) ; pas de couleur hardcodée.

Verdict : 4/4 PASS, aucun fix critique requis avant commit.

## Deviations from Plan

None — plan exécuté tel qu'écrit. Le getter canonique `revenuBrutAnnuelCouple` existait déjà dans le modèle ; le helper s'y délègue plutôt que de recopier la somme (plus propre que l'`action` littérale qui décrivait `salaireBrutMensuel×nombreDeMois + conjoint×nombreDeMois` — comportement identique, source unique respectée).

## Deferred Issues (out of scope)

Logué dans `.planning/phases/mint-illogism-fixes/deferred-items.md` (entrée plan 15) : la même citation fausse « LCC art. 28 » pour le mortgage-cap 33% subsiste dans d'autres fichiers backend (`_payload.py`, `coach_tools.py`, `anthropic_defer_loading_adapter.py`) — HORS du one-liner autorisé par le plan (truth #2 : SEULE exception backend). À traiter dans un PR backend dédié « legal-citation sweep ». NE PAS toucher `educational_content_service.py:228,233,234` (LCC art.17/30 pour le crédit à la consommation = citation correcte là).

## Known Stubs

Aucun. Pas de valeur vide/placeholder introduite ; les helpers retournent `null` uniquement quand ni prefill ni profil ne sont disponibles (fallback légitime vers le défaut écran existant).

## Self-Check: PASSED

- FOUND: apps/mobile/test/screens/affordability_prefill_test.dart
- FOUND: .planning/phases/mint-illogism-fixes/mint-illogism-fixes-15-w4-affordability-unify-lcc-SUMMARY.md
- FOUND commit: c15416ea4 (Task 1 — affordability unification)
- FOUND commit: 649a3a6bd (Task 2 — legal citation fix)

## Post-review gap closure (Codex W4)

Revue Codex CLI indépendante du W4 mergé (plans 12-15), 4 P2 + 2 P3 vérifiés par l'orchestrateur. Tous corrigés, groupés en commits logiques. Branche `qa/runtime-navigation-spine-20260602`, sequential executor sur la working tree principale (pas de worktree).

### Findings corrigés

**Groupe 1 — Divorce incomplet (1 P2 + 2 P3) — commit `d7ed25240`**

- **(a) P2 — Hero fabriquait une certitude.** `_buildDivorceHeroCard` (`apps/mobile/lib/screens/divorce_simulator_screen.dart`) affichait inconditionnellement `CHF 0` + un transfert quand `r.lppSplit.isIncomplete`. Le premier résultat vu par l'utilisateur présentait donc une certitude que la donnée ne supporte pas. Fix : quand `isIncomplete`, le hero rend l'état « donnée requise » (nouvelles clés `divorceHeroDonneeRequiseValue/Label`, narrative = `divorceSplitDonneeRequise`), aucun transfert fabriqué.
- **(b) P3 — `totalLpp` remis à zéro.** Le résultat incomplet (`apps/mobile/lib/services/life_events_service.dart`) jetait le total LPP actuel CONNU (`totalLpp: 0`). Fix : on conserve `totalLpp` (somme actuelle des deux conjoints) ; seuls les champs split/transfert restent bloqués.
- **(c) P3 — Label légalement faux.** « Total LPP (pendant le mariage) » alors que la valeur affichée est le total ACTUEL. Fix : label corrigé dans les 6 ARBs (FR « Avoir LPP total (actuel) », équivalents en/de/es/it/pt), `flutter gen-l10n`.
- Tests : `life_events_divorce_test.dart` (le résultat incomplet conserve `totalLpp == 400000`) + `divorce_simulator_screen_test.dart` (hero incomplet montre l'état donnée-requise, aucun « Transfert de » rendu). Branche complète couverte au niveau service (transfert calculé + `isIncomplete == false`) — pas de pilotage de deux modals imbriqués (Karpathy #2/#3, couverture équivalente non-fragile).

**Finding 2 — P2 — Levier `3a_max` fuite pour `canContribute3a == false` — commit `d0df20471`**

`_computeCapImpacts` Cap 2 (`apps/mobile/lib/services/budget_living_engine.dart`) utilisait le plafond fixe `pilier3aPlafondAvecLpp` en ignorant l'éligibilité → un profil FATCA/non-éligible recevait quand même « Levier: 3a_max » via `context_injector_service.dart`. Fix : Cap 2 utilise `Pillar3aRoomCalculator.annualCeiling(profile)` (0.0 pour non-éligible, room income-based pour indépendants) ; plafond 0 → aucun impact `3a_max`. Tests : profil expatUs (nationality 'US') → aucun `3a_max` ; contrôle positif (suisse éligible + gap 3a) → `3a_max` présent.

**Finding 3 — P2 — `cap_sequence` AVS jetait les inputs de lacune — commit `423bfeed8`**

`_estimateAvsMonthly` (`apps/mobile/lib/services/cap_sequence_engine.dart`) ne passait que `anneesContribuees` + salaire à `AvsCalculator`, ignorant `arrivalAge` et `lacunesAVS` → divergence vs `minimal_profile_service.compute` (plan 13). Fix : transmet `arrivalAge`, `lacunes` (lacunesAVS), `isFemale`, et l'année de naissance effective, en miroir de l'estimateur minimal. Contrat null préservé : ni `anneesContribuees` ni `arrivalAge` exploitable → `null`. Tests : `arrivalAge=43` sans `anneesContribuees` → `cap_sequence` AVS == `minimal_profile` AVS (parité au centime) ; `lacunesAVS` plumbées → parité `AvsCalculator`.

**Finding 4 — P2 — Citation fausse « LCC art. 28 » dans les chemins runtime backend — commit `17f0adc9c`**

Plan 15 n'avait corrigé que `lucidity.py`. La LCC (crédit à la consommation) EXCLUT le crédit hypothécaire → le plafond de charge 33% doit citer « Directives ASB (FINMA) » (label standardisé plan 15). Fix : `coach_tools.py` (get_cap_status), `anthropic_defer_loading_adapter.py` (header + descriptions affordability/amortization/saron/debt_ratio/allocation — corpus Tool Search BM25), `_payload.py` (exemple docstring L4 + exemple de format + header module), test `test_lucidity_payloads.py` (assertions périmées). `educational_content_service.py:228,233,234` (LCC art.17/30, crédit conso) laissé intact = citation correcte. Ceci ferme l'item « Deferred Issues » ci-dessus (sweep citation backend dédié).

### Gates (déterministes)

- `flutter analyze` (full) : `No issues found! (ran in 6.9s)`.
- Flutter tests : `test/services/` → `5886 All tests passed!` ; `test/screens/` → `+887 ~8 All tests passed!` (8 skipped pré-existants). Fichiers ciblés (`life_events_divorce_test.dart`, `budget_living_engine_test.dart`, `financial_parity_test.dart`, `cap_sequence_engine_test.dart`, `divorce_simulator_screen_test.dart`) → `+153 All tests passed!`.
- Backend : `cd services/backend && python3 -m pytest tests/ -q` → `7586 passed, 116 skipped, 4 xfailed in 91.40s`.
- Lint accent FR (`accent_lint_fr.py --file app_fr.arb`) : aucune violation. Hooks lefthook (banned-terms-arb-gate, no-3a-ceiling-as-tax-saving-gate, etc.) verts sur chaque commit.

### Commits de la clôture

| # | Hash | Finding(s) | Périmètre |
|---|------|-----------|-----------|
| 1 | `d7ed25240` | Groupe 1 (P2+P3+P3) | divorce_simulator_screen + life_events_service + 6 ARBs + gen-l10n + tests |
| 2 | `d0df20471` | Finding 2 (P2) | budget_living_engine + test |
| 3 | `423bfeed8` | Finding 3 (P2) | cap_sequence_engine + financial_parity_test |
| 4 | `17f0adc9c` | Finding 4 (P2) | backend coach_tools + adapter + _payload + test |

STATE.md / ROADMAP.md non modifiés (hors scope de la clôture, per objectif).
