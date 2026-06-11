---
phase: mint-illogism-fixes
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - apps/mobile/lib/models/coach_profile.dart
  - apps/mobile/lib/services/minimal_profile_service.dart
  - apps/mobile/lib/services/financial_core/monte_carlo_service.dart
  - apps/mobile/test/services/financial_parity_test.dart
autonomous: true
requirements:
  - MATRIX-salarie_swiss-1
  - MATRIX-independent_no_lpp-4
  - MATRIX-expat_us-3
  - MATRIX-frontalier-2
  - MATRIX-frontalier-5
  - MATRIX-cadre_divorce_hypo-2
  - MATRIX-couple_acheteurs-2
  - MATRIX-returning_swiss_gaps-3
  - MATRIX-returning_swiss_gaps-4
must_haves:
  truths:
    - "Pour un même input (âge, salaire brut, arrivalAge), l'avoir LPP estimé est IDENTIQUE quel que soit le moteur (minimal_profile_service, coach_profile, monte_carlo) — au centime."
    - "Le salaire coordonné est borné [3780, 64260] sur TOUS les chemins (LPP art.8)."
    - "L'intérêt projeté = lpp.min_interest_rate (1.25%) registry, plus aucun 1.01 hardcodé."
    - "Un profil arrivé en Suisse à 43 ans démarre l'accumulation LPP à 43, pas à 25, sur les DEUX moteurs."
    - "Un profil de 25 ans a un avoir LPP estimé = 0 (contrôle négatif jeune_diplome-1, ne PAS régresser)."
  artifacts:
    - path: "apps/mobile/test/services/financial_parity_test.dart"
      provides: "Tests de parité W1 (squelette Wave 0 + groupe « Avoir LPP ») — anti-régression de toute la classe DIVERGENT"
      min_lines: 60
    - path: "apps/mobile/lib/models/coach_profile.dart"
      provides: "_estimateLppAvoir délègue à LppCalculator (plus de clamp min-only ni 1.01 hardcodé)"
      contains: "LppCalculator"
  key_links:
    - from: "apps/mobile/lib/models/coach_profile.dart"
      to: "apps/mobile/lib/services/financial_core/lpp_calculator.dart"
      via: "délégation _estimateLppAvoir → LppCalculator.projectToRetirement / computeSalaireCoordonne"
      pattern: "LppCalculator\\.(projectToRetirement|computeSalaireCoordonne)"
    - from: "apps/mobile/lib/services/minimal_profile_service.dart"
      to: "apps/mobile/lib/services/financial_core/lpp_calculator.dart"
      via: "délégation _estimateLppBalance → LppCalculator avec arrivalAge"
      pattern: "LppCalculator\\."
---

<objective>
W1 quantité #1 — Avoir LPP estimé : UNE source canonique (`LppCalculator`, financial_core L1) pour l'estimation d'avoir LPP par âge×salaire. Élimine les écarts mesurés +15.4% (gross 102k) à +105% (gross 162k) entre `coach_profile._estimateLppAvoir` et `minimal_profile_service._estimateLppBalance`, et la 3e boucle inline de `monte_carlo_service`.

Purpose: ferme la cause racine #1 de la matrice (NEVER #3 CLAUDE.md — pas de calcul dupliqué L1). C'est le re-câblage, pas une création : la cible canonique existe et est correcte.
Output: 2 estimateurs délégués + boucle Monte Carlo alignée registry + squelette de test de parité W1 (Wave 0 de la phase).
</objective>

<execution_context>
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/workflows/execute-plan.md
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/phases/mint-illogism-fixes/mint-illogism-fixes-CONTEXT.md
@.planning/reports/MATRIX-illogismes-2026-06-09.md (§2 « Avoir LPP », findings cités en requirements)
@apps/mobile/lib/services/financial_core/lpp_calculator.dart
@apps/mobile/lib/constants/social_insurance.dart

<interfaces>
Canonique (lpp_calculator.dart, fonctions statiques pures) :
- `static double computeSalaireCoordonne(double grossAnnualSalary)` (:201-205) — double clamp [lppSalaireCoordMin=3780, lppSalaireCoordMax=64260].
- `static double projectToRetirement({...})` (:67) — projection avec intérêt registry.
- `static double adjustedConversionRate({...})` (:43-52) — hors scope de ce plan (plan 02).
Constantes registry (social_insurance.dart) : `:63` lppSalaireCoordMax=64260 · `:92` lpp.min_interest_rate=1.25.
Sites divergents : coach_profile.dart:3577-3591 (`_estimateLppAvoir`, clamp min-only via `double.infinity`, `total * 1.01` hardcodé, callers :2857 user / :3156 conjoint, `startAge = arrivalAge.clamp(25,65)` à :3584) ; minimal_profile_service.dart:196-209 (`_estimateLppBalance`, clamps OK + 1.25% mais PAS de paramètre arrivalAge) ; monte_carlo_service.dart:221-247 (boucle inline salaireCoord/bonification).
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Wave 0 — squelette financial_parity_test.dart + groupe « Avoir LPP » RED</name>
  <files>apps/mobile/test/services/financial_parity_test.dart</files>
  <read_first>
    - apps/mobile/lib/services/financial_core/lpp_calculator.dart (signatures exactes projectToRetirement / computeSalaireCoordonne)
    - apps/mobile/lib/models/coach_profile.dart:2850-2859, 3577-3591 (chemin public qui déclenche l'estimation : fromWizardAnswers sans valeur LPP saisie → prevoyance.avoirLppTotal estimé)
    - apps/mobile/lib/services/minimal_profile_service.dart:57-74, 196-209 (chemin public compute() → résultat exposant l'avoir/lppMonthly)
    - Lignes matrice : salarie_swiss-1, cadre_divorce_hypo-2, returning_swiss_gaps-3/-4, jeune_diplome-1
  </read_first>
  <behavior>
    - Test 1 (salarie_swiss-1): âge 42, brut 102000 → avoir via CoachProfile.fromWizardAnswers == avoir via MinimalProfileService.compute == LppCalculator.projectToRetirement, et salaire coordonné == 64260 (plafonné).
    - Test 2 (cadre_divorce_hypo-2): âge 52, brut 162000 → trois chemins égaux au centime (cas où l'écart historique était +105%).
    - Test 3 (jeune_diplome-1, contrôle négatif): âge 25, brut 78000 → avoir == 0 sur tous les chemins.
    - Test 4 (returning_swiss_gaps-4): âge 48, brut 120000, arrivalAge 43 → les DEUX moteurs démarrent l'accumulation à 43 (avoir ≈ 5 ans de cotisation, pas 23).
    - Structure : `group('Parity W1 — Avoir LPP', ...)` dans un fichier qui recevra les groupes Rente/Remplacement/3a des plans 02-05.
  </behavior>
  <action>Créer `apps/mobile/test/services/financial_parity_test.dart` avec le groupe « Avoir LPP ». Harnais : passer par les surfaces PUBLIQUES (CoachProfile.fromWizardAnswers avec q_* salary/âge et aucun avoir saisi ; MinimalProfileService.compute) — ne pas tester les méthodes privées. Référence attendue = LppCalculator.projectToRetirement avec computeSalaireCoordonne. Lancer le test et CONSIGNER l'état RED initial (valeurs divergentes observées) dans le message de commit `test(mint-illogism-fixes-01): add failing parity tests for avoir LPP` — c'est la baseline RED exigée par VALIDATION.md Wave 0.</action>
  <acceptance_criteria>
    - `apps/mobile/test/services/financial_parity_test.dart` existe avec ≥4 cas du groupe « Avoir LPP » couvrant les inputs exacts des lignes matrice citées.
    - `cd apps/mobile && flutter test test/services/financial_parity_test.dart` ÉCHOUE avant fix (RED documenté avec les valeurs divergentes, ex. 98627.20 vs 113803.81 pour 42/102000) — sortie citée dans le commit.
    - Aucun accès à des membres privés `_estimate*` depuis le test.
  </acceptance_criteria>
  <verify>
    <automated>cd apps/mobile && flutter test test/services/financial_parity_test.dart 2>&1 | tail -20</automated>
  </verify>
  <done>Groupe « Avoir LPP » committé RED avec citations des valeurs divergentes ; squelette prêt à recevoir les groupes des plans 02-05.</done>
</task>

<task type="auto">
  <name>Task 2: Re-câbler les 3 sites vers LppCalculator (clamp 64260 + 1.25% + arrivalAge)</name>
  <files>apps/mobile/lib/models/coach_profile.dart, apps/mobile/lib/services/minimal_profile_service.dart, apps/mobile/lib/services/financial_core/monte_carlo_service.dart</files>
  <read_first>
    - apps/mobile/lib/services/financial_core/lpp_calculator.dart (intégralité — signatures et sémantique de projectToRetirement)
    - apps/mobile/lib/models/coach_profile.dart:3577-3591 + callers :2857, :3156
    - apps/mobile/lib/services/minimal_profile_service.dart:196-209 + caller
    - apps/mobile/lib/services/financial_core/monte_carlo_service.dart:221-247
  </read_first>
  <action>Strangler-fig (D-11) : (1) `coach_profile._estimateLppAvoir` devient une façade qui délègue à `LppCalculator.projectToRetirement` — salaire coordonné via `LppCalculator.computeSalaireCoordonne` (clamp [3780, 64260], ferme frontalier-5), intérêt via registry `lpp.min_interest_rate=1.25` (supprimer le `* 1.01` hardcodé), conserver le support `arrivalAge` (startAge = arrivalAge.clamp(25,65)). (2) `minimal_profile_service._estimateLppBalance` délègue de même ET gagne un paramètre `int? arrivalAge` plumbé depuis le profil (ferme returning_swiss_gaps-4 : démarrage à l'arrivée, plus toujours 25). (3) `monte_carlo_service.dart:221-247` : la boucle stochastique reste, mais le salaire coordonné et les taux de bonification passent par `LppCalculator.computeSalaireCoordonne` + le registry (plus aucune constante LPP inline). Karpathy #3 : ne toucher QUE ces hunks ; mettre à jour les goldens/snapshots cassés sans les contourner.</action>
  <acceptance_criteria>
    - `grep -n "double.infinity" apps/mobile/lib/models/coach_profile.dart` ne matche plus dans _estimateLppAvoir ; `grep -n "1\.01" apps/mobile/lib/models/coach_profile.dart` ne matche plus dans le bloc 3577-3591.
    - `grep -c "LppCalculator\." apps/mobile/lib/models/coach_profile.dart` ≥ 1 et `grep -c "LppCalculator\." apps/mobile/lib/services/minimal_profile_service.dart` ≥ 1.
    - `cd apps/mobile && flutter test test/services/financial_parity_test.dart` exit 0 (GREEN — oracle matrice re-run : 42/102000 → valeur unique, coord 64260 ; 25/78000 → 0 ; 48/120000/arrivée 43 → accumulation 5 ans).
    - `cd apps/mobile && flutter analyze` exit 0 et `flutter test test/services/ test/models/` exit 0 (goldens mis à jour si nécessaire, pas contournés).
  </acceptance_criteria>
  <verify>
    <automated>cd apps/mobile && flutter test test/services/financial_parity_test.dart && flutter analyze</automated>
  </verify>
  <done>Les 3 sites délèguent au canonique ; parité au centime sur les 4 cas matrice ; suite analyze/tests verte. Ferme : salarie_swiss-1, independent_no_lpp-4, expat_us-3, frontalier-2, frontalier-5, cadre_divorce_hypo-2, couple_acheteurs-2, returning_swiss_gaps-3, returning_swiss_gaps-4 (oracles matrice re-run requis avant tout claim « fermé », 0-TRUST §9).</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries
| Boundary | Description |
|----------|-------------|
| moteurs d'estimation → surfaces UI | un chiffre financier faux affiché à l'utilisateur = atteinte à l'intégrité (LSFin) |

## STRIDE Threat Register
| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-ILF-01-01 | Tampering (intégrité des données affichées) | _estimateLppAvoir / _estimateLppBalance | mitigate | source unique LppCalculator + test de parité au centime (financial_parity_test.dart) |
| T-ILF-01-02 | Repudiation (régression silencieuse) | futurs appels divergents | mitigate | le test de parité encode l'oracle matrice — toute régression casse CI |
</threat_model>

<verification>
- `cd apps/mobile && flutter analyze && flutter test` (suite complète) exit 0.
- Oracles matrice re-run verts pour les 9 finding-IDs en requirements (valeurs uniques, coord plafonné).
- Aucun nouveau package installé (pas de gate de légitimité requis).
</verification>

<success_criteria>
- 9 lignes de matrice fermées avec citation (commande + sortie) dans le SUMMARY.
- financial_parity_test.dart en place comme harnais des plans 02-05.
</success_criteria>

<output>
Create `.planning/phases/mint-illogism-fixes/mint-illogism-fixes-01-SUMMARY.md` when done. Mettre à jour `.planning/reports/MATRIX-illogismes-2026-06-09.md` n'est PAS autorisé (read-only contrat) — consigner les fermetures dans le SUMMARY + VALIDATION.md Per-Task Map.
</output>
