---
phase: mint-illogism-fixes
plan: 13
subsystem: financial-core
tags: [avs, gapfactor, lacunes, rente-trouee, minimal-profile, cap-sequence, onboarding, i18n, parity, jeune-diplome, returning-swiss]

# Dependency graph
requires:
  - phase: mint-illogism-fixes-11
    provides: ConfidenceScorer canonical (confidence gate) — wave dependency, not a direct code link here
  - phase: mint-illogism-fixes-06
    provides: q_avs_lacunes_status + q_avs_arrival_year peuplés à l'onboarding (la donnée lacunes EXISTE au moment où ces sites calculent)
provides:
  - "MinimalProfileService.compute accepte lacunes/anneesContribuees et les transmet (avec arrivalAge) à AvsCalculator — gapFactor honoré, fin de la rente MAX 2520 forcée pour un Suisse de retour"
  - "coach_profile_provider dérive anneesContribuees/arrivalAge AVANT le calcul minimal et les plumbe (cohérence intra-app : même chiffre que response_card / forecaster)"
  - "cap_sequence_engine._estimateAvsMonthly délègue à AvsCalculator (RAMD + années réelles) — dernier estimateur AVS divergent canonicalisé, suppression de la formule plate income-blind 2520×years/44"
  - "MintSceneRenteTrouee calcule AVS via AvsCalculator AVEC arrivalAge/lacunes + LPP via LppCalculator.projectToRetirement (suppression du forfait gross*0.34/12)"
  - "Étiquette « hypothèse : carrière complète » (gapFactor=1.0 ET âge<30) — jeune_diplome-2 fermé"
  - "OnboardingProvider.avsArrivalAge + avsGaps : getters dérivés (même logique que CoachProfile.fromWizardAnswers) — source unique du gapFactor pour la scène"
  - "ARB ×6 onboardingSceneFullCareerAssumption"
  - "financial_parity_test « Parity W4 — Rente AVS » (4 cas) + storyboard « W4 — Scène rente_trouée honnête » (3 cas) — régression permanente"
affects: [avs-calculator, minimal-profile, cap-sequence-engine, onboarding-scene, financial-parity, matrix-returning-swiss-gaps, matrix-jeune-diplome]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Un seul estimateur AVS canonique dans toute l'app (AvsCalculator) : minimal_profile, cap_sequence, response_card, forecaster, scène rente_trouée passent désormais arrivalAge/lacunes au même moteur RAMD-based — plus de divergence ×2 (2520 vs 1260) ni de formule plate income-blind"
    - "Le gapFactor (dérivé d'arrivalAge/lacunes) n'est plus ignoré silencieusement : pour le profil le plus career-contingent (jeune sans historique) le chiffre le plus career-certain (carrière complète projetée) est étiqueté hypothèse, pas vendu tel quel"
    - "Dérivation lacunes/arrivalAge factorisée en getters du provider (avsArrivalAge/avsGaps) qui répliquent CoachProfile.fromWizardAnswers — un seul algorithme de gap, deux consommateurs (scène onboarding + profil coach)"

key-files:
  created:
    - .planning/_walker/illogism-fixes/w4/README.md
  modified:
    - apps/mobile/lib/services/minimal_profile_service.dart
    - apps/mobile/lib/services/cap_sequence_engine.dart
    - apps/mobile/lib/providers/coach_profile_provider.dart
    - apps/mobile/lib/screens/onboarding/mvp_wedge/scenes/mint_scene_rente_trouee.dart
    - apps/mobile/lib/screens/onboarding/mvp_wedge/onboarding_provider.dart
    - apps/mobile/lib/screens/onboarding/mvp_wedge/onboarding_shell_screen.dart
    - apps/mobile/lib/l10n/app_fr.arb
    - apps/mobile/lib/l10n/app_en.arb
    - apps/mobile/lib/l10n/app_de.arb
    - apps/mobile/lib/l10n/app_es.arb
    - apps/mobile/lib/l10n/app_it.arb
    - apps/mobile/lib/l10n/app_pt.arb
    - apps/mobile/lib/l10n/app_localizations.dart
    - apps/mobile/lib/l10n/app_localizations_fr.dart
    - apps/mobile/lib/l10n/app_localizations_en.dart
    - apps/mobile/lib/l10n/app_localizations_de.dart
    - apps/mobile/lib/l10n/app_localizations_es.dart
    - apps/mobile/lib/l10n/app_localizations_it.dart
    - apps/mobile/lib/l10n/app_localizations_pt.dart
    - apps/mobile/test/services/financial_parity_test.dart
    - apps/mobile/test/screens/onboarding/mvp_wedge_storyboard_test.dart
    - .planning/phases/mint-illogism-fixes/mint-illogism-fixes-VALIDATION.md

key-decisions:
  - "minimal_profile_service.compute reçoit DEUX nouveaux paramètres (lacunes + anneesContribuees) plutôt que de re-dériver le gapFactor en interne : la dérivation des lacunes vit déjà dans le provider (coach_profile_provider) et dans CoachProfile.fromWizardAnswers. Réimplémenter la dérivation dans le service créerait un 3e algorithme de gap. On plumbe la donnée déjà calculée — c'est le chemin de référence de forecaster_service:826-835."
  - "Le caller coach_profile_provider a été REORDONNÉ : la dérivation avsContributionYears/arrivalAge (qui était APRÈS l'appel MinimalProfileService.compute) est remontée AVANT pour pouvoir alimenter le calcul. C'est la racine du bug returning_swiss_gaps-1 : la donnée était disponible juste sous l'appel mais jamais transmise."
  - "cap_sequence._estimateAvsMonthly utilise currentAge ?? years comme garde quand l'âge est inconnu : anneesContribuees seul pilote alors le gapFactor (currentAge=years ⇒ dérivation 21..years bornée). Le contrat existant (années nulles → null) est préservé — pas de régression du test « années nulles → null »."
  - "La scène MintSceneRenteTrouee garde un constructeur const-compatible (arrivalAge optionnel, lacunes default 0) pour ne pas casser le storyboard existant CJT-018 qui construit `const MintSceneRenteTrouee(...)`. Surface minimale : 2 params ajoutés, label conditionnel ajouté, source de calcul AVS+LPP changée — aucune restructuration de layout."
  - "L'étiquette « hypothèse : carrière complète » est gatée gapFactor==1.0 ET âge<30 (et pas seulement gapFactor==1.0) : un profil mûr (48 ans) sans lacune a objectivement quasi-cotisé sa carrière, l'hypothèse n'est pertinente (et honnête) que pour le jeune qui n'a pas encore d'historique. Test dédié vérifie qu'un profil mûr sans lacune ne porte PAS l'étiquette."
  - "LPP de la scène : LppCalculator.projectToRetirement(currentBalance: 0, ...) — accumulation salaire-pondérée dès 25 ans, taux conv. min 6.8%, fourchette via caisseReturn 1.5%/3.5%. Mirroir exact de minimal_profile_service:136-143. Le forfait gross*0.34/12 disparaît du code (ne subsiste qu'en commentaire documentant ce qui a été retiré)."

# Metrics
metrics:
  duration: ~75 min
  completed: 2026-06-11
  tasks: 2
  commits: 2
  files_created: 1
  files_modified: 21
---

# Phase mint-illogism-fixes Plan 13: W4 GapFactor AVS Summary

**One-liner:** Canonicalisé le gapFactor AVS sur les derniers sites divergents — `minimal_profile_service` et le caller `coach_profile_provider` plumbent désormais `arrivalAge`/`lacunes`/`anneesContribuees` à `AvsCalculator` (un Suisse de retour arrivé à 43 ans voit une rente réduite par le trou de cotisation, plus jamais la rente MAX 2520 forcée), `cap_sequence_engine._estimateAvsMonthly` délègue au moteur RAMD-based (suppression de la formule plate income-blind `2520×years/44`), et la scène d'onboarding `MintSceneRenteTrouee` — qui s'appelle « rente TROUÉE » mais calculait « sur carrière complète » — reflète enfin le trou (AVS via `AvsCalculator` avec lacunes + LPP via `LppCalculator.projectToRetirement` au lieu du forfait `gross*0.34/12`), avec une étiquette « hypothèse : carrière complète » pour le jeune (<30 ans) sans lacune dont le gapFactor=1.0 n'est plus silencieux.

## What Was Built

### Task 1 — Plumbing arrivalAge/lacunes + délégation cap_sequence (commit `e201cf8d6`)
- `minimal_profile_service.dart` : ajout des paramètres `lacunes` (default 0) et `anneesContribuees`, transmis avec `arrivalAge` à `AvsCalculator.computeMonthlyRente` (chemin de référence `forecaster_service:826-835`).
- `coach_profile_provider.dart` : la dérivation `avsContributionYears`/`arrivalAge` (auparavant APRÈS l'appel) est remontée AVANT le `MinimalProfileService.compute`, et `minimalArrivalAge` + `avsContributionYears` y sont plumbés. C'est la racine du bug : la donnée était sous l'appel mais jamais transmise.
- `cap_sequence_engine.dart` : `_estimateAvsMonthly` délègue à `AvsCalculator` (RAMD + années réelles) ; la formule plate `2520 * years / 44` (income-blind, +655..+998 CHF/mois de surestimation §2) est supprimée du code. Test seam `debugEstimateAvsMonthly` ajouté pour la parité.
- `financial_parity_test.dart` : groupe « Parity W4 — Rente AVS » (4 cas : minimal_profile arrivalAge=43 == canonique ≈1260 / pas de régression sans lacune / cap_sequence parité RAMD-based / cap_sequence années nulles → null).

### Task 2 — Scène honnête + hypothèse jeune étiquetée (commit `d85263019`)
- `mint_scene_rente_trouee.dart` : AVS via `AvsCalculator` AVEC `arrivalAge`/`lacunes` ; LPP via `LppCalculator.projectToRetirement` (forfait `0.34` retiré) ; étiquette `onboardingSceneFullCareerAssumption` rendue quand `gapFactor==1.0 ET âge<30`.
- `onboarding_provider.dart` : getters `avsArrivalAge` + `avsGaps` répliquant la dérivation de `CoachProfile.fromWizardAnswers` (source unique du gapFactor).
- `onboarding_shell_screen.dart` : plumbe `arrivalAge`/`lacunes` à la scène (branches `retraite` + `explorer`).
- ARB ×6 `onboardingSceneFullCareerAssumption` + `flutter gen-l10n` (parité 6915 clés).
- `mvp_wedge_storyboard_test.dart` : groupe « W4 — Scène rente_trouée honnête » (3 widget tests : profil à lacunes sans étiquette / jeune 25 ans avec étiquette / profil mûr 48 ans sans étiquette).
- `.planning/_walker/illogism-fixes/w4/README.md` : spec des 2 captures device-proof déférées.

## Verification (deterministic citations)

- `flutter test test/services/financial_parity_test.dart` → **43/43 All tests passed** (dont 4 nouveaux W4 Rente AVS).
- `flutter test test/screens/onboarding/mvp_wedge_storyboard_test.dart` → **61/61 All tests passed** (dont 3 nouveaux W4 scène).
- `flutter analyze` (full mobile) → **No issues found! (ran in 6.6s)**.
- `grep -n "2520" lib/services/cap_sequence_engine.dart` → **1 occurrence, en commentaire ligne 612** (documente l'ancienne formule retirée ; 0 code live).
- `grep -n "0\.34" lib/screens/.../mint_scene_rente_trouee.dart` → **2 occurrences, toutes en commentaires** (0 code live).
- `python3 tools/checks/arb_parity.py` → **OK — 6 locale(s) parity (reference=fr, 6915 keys each)**.
- `python3 tools/checks/banned_terms_arb.py` → **OK — 6 locale(s) clean**.
- `accent_lint_fr.py --file <chaque fichier modifié>` → **exit 0** (aucune violation).
- Pre-commit lefthook (Task 2) : arb-parity-gate / banned-terms-arb-gate / no-3a-ceiling-as-tax-saving / prefer-mint-* / wiki-lint → tous **OK / no FAIL-level**.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Réordonnancement du caller coach_profile_provider**
- **Found during:** Task 1.
- **Issue:** `arrivalAge` et `avsContributionYears` étaient dérivés APRÈS l'appel `MinimalProfileService.compute`, rendant impossible le plumbing sans réordonner.
- **Fix:** Bloc de dérivation AVS remonté avant l'appel ; `minimalArrivalAge` capturé dans la branche `isExpat`. Aucune logique métier modifiée, seul l'ordre.
- **Files modified:** `apps/mobile/lib/providers/coach_profile_provider.dart`.
- **Commit:** `e201cf8d6`.

**2. [Rule 2 - Critical functionality] Test seam debugEstimateAvsMonthly**
- **Found during:** Task 1.
- **Issue:** `_estimateAvsMonthly` est privé ; impossible d'asserter la parité cap_sequence/canonique depuis le test.
- **Fix:** Ajout d'un accesseur `debugEstimateAvsMonthly` (pointe simplement vers le privé, pas de logique nouvelle).
- **Files modified:** `apps/mobile/lib/services/cap_sequence_engine.dart`.
- **Commit:** `e201cf8d6`.

## Deferred Gates (device-gate orchestrateur)

Conformément au 0-TRUST (CLAUDE.md §9) et au précédent W1 (commit `d755c06af` — déférence device-proof à l'orchestrateur pour cause de contrainte build worktree `.nosync`) :

- **Device-proof sim** : `xcrun simctl list devices booted` → **NO_BOOTED_SIM** au moment de l'exécution. L'exécuteur séquentiel ne boote pas de sim / ne lance pas de build. Les 2 captures (`scene-lacunes.png` + `scene-jeune-etiquete.png`) sont spécifiées dans `.planning/_walker/illogism-fixes/w4/README.md` et à produire par le device-gate orchestrateur après merge de la vague. **Aucune capture fabriquée.**
- **Panel design 4-personnes** : l'exécuteur séquentiel n'a pas la capacité de spawn sub-agents dans ce contexte. La modification de la scène est conservatrice (1 label italique ajouté sous le sous-titre existant + changement de la source de calcul AVS/LPP, aucune restructuration de layout / couleur / typo — tous les gates `prefer-mint-*` sont GREEN), ce qui borne le risque visuel. Panel déféré à l'orchestrateur avant tout claim « ready ».

**Statut honnête :** code-shipped sur la branche, parité + analyze + lints verts (tests verts ≠ feature working — CLAUDE.md §9.2). Validation end-to-end sur sim PENDING au device-gate.

## Requirements Closed (avec citations)

- **MATRIX-returning_swiss_gaps-1** + **§2 « Rente AVS »** → Task 1 (`e201cf8d6`), parité W4 4/4.
- **MATRIX-returning_swiss_gaps-2** → Task 2 (`d85263019`), scène à lacunes ≠ carrière complète (widget test).
- **MATRIX-jeune_diplome-2** → Task 2 (`d85263019`), étiquette « hypothèse : carrière complète » (widget test jeune 25 ans).

## Known Stubs

Aucun. Tous les calculs sont câblés sur les moteurs canoniques (`AvsCalculator`, `LppCalculator`) ; aucune valeur vide/placeholder n'alimente le rendu.

## Self-Check: PASSED

- Created files FOUND: SUMMARY.md, `.planning/_walker/illogism-fixes/w4/README.md`, minimal_profile_service.dart, cap_sequence_engine.dart, mint_scene_rente_trouee.dart.
- Commits FOUND: `e201cf8d6` (Task 1), `d85263019` (Task 2).
