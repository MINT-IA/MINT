---
phase: mint-illogism-fixes
plan: 13
type: execute
wave: 11
depends_on: [mint-illogism-fixes-11]
files_modified:
  - apps/mobile/lib/services/minimal_profile_service.dart
  - apps/mobile/lib/screens/onboarding/mvp_wedge/scenes/mint_scene_rente_trouee.dart
  - apps/mobile/lib/services/cap_sequence_engine.dart
  - apps/mobile/lib/l10n/app_fr.arb
  - apps/mobile/lib/l10n/app_en.arb
  - apps/mobile/lib/l10n/app_de.arb
  - apps/mobile/lib/l10n/app_es.arb
  - apps/mobile/lib/l10n/app_it.arb
  - apps/mobile/lib/l10n/app_pt.arb
  - apps/mobile/test/services/financial_parity_test.dart
autonomous: true
requirements:
  - MATRIX-returning_swiss_gaps-1
  - MATRIX-returning_swiss_gaps-2
  - MATRIX-jeune_diplome-2
must_haves:
  truths:
    - "Le minimal profile passe arrivalAge/lacunes à AvsCalculator.computeMonthlyRente : un Suisse de retour (arrivalAge=43) voit ~1260 CHF/mois, plus jamais la rente MAX 2520 (gapFactor=1.0 forcé)."
    - "La scène MintSceneRenteTrouee reflète le trou de cotisation (c'est son NOM) : AVS avec lacunes + LPP via LppCalculator (plus le forfait 0.34 inline)."
    - "Pour le jeune (25 ans), gapFactor=1.0 n'est plus silencieux : étiqueté « hypothèse : carrière complète » (le plus career-contingent ne reçoit plus le chiffre le plus career-certain)."
    - "cap_sequence_engine._estimateAvsMonthly (formule plate income-blind 2520×années/44) délègue à AvsCalculator (RAMD-based) — §2 « Rente AVS »."
  artifacts:
    - path: "apps/mobile/test/services/financial_parity_test.dart"
      provides: "Groupe « Rente AVS » : lacunes plumbées + parité cap_sequence/canonique"
      contains: "Rente AVS"
  key_links:
    - from: "apps/mobile/lib/services/minimal_profile_service.dart"
      to: "AvsCalculator.computeMonthlyRente"
      via: "arrivalAge/anneesContribuees transmis"
      pattern: "arrivalAge"
    - from: "apps/mobile/lib/screens/onboarding/mvp_wedge/scenes/mint_scene_rente_trouee.dart"
      to: "AvsCalculator + LppCalculator"
      via: "calculs canoniques au lieu de carrière complète + forfait 0.34"
      pattern: "AvsCalculator|LppCalculator"
---

<objective>
W4 — GapFactor AVS : `minimal_profile_service.dart:92-98` appelle `computeMonthlyRente` SANS arrivalAge/lacunes (gapFactor=1.0 forcé) alors que `response_card_service.dart:767` et `forecaster_service.dart:829` les passent — incohérence intra-app ×2 (2520 vs 1260). La scène `MintSceneRenteTrouee` (:47-51) calcule « sur carrière complète » — ironique pour une scène nommée « rente trouée » — et sa LPP (:57) est un forfait `gross*0.34/12` qui bypasse LppCalculator. Inclut la délégation du dernier estimateur AVS divergent (`cap_sequence_engine.dart:609-614`, §2).

Purpose: ferme returning_swiss_gaps-1, returning_swiss_gaps-2, jeune_diplome-2, §2 « Rente AVS ».
Output: lacunes plumbées partout + scène honnête + hypothèse jeune étiquetée.
</objective>

<execution_context>
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/workflows/execute-plan.md
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/reports/MATRIX-illogismes-2026-06-09.md (returning_swiss_gaps-1/-2, jeune_diplome-2, §2 Rente AVS)

<interfaces>
Canonique : AvsCalculator.computeMonthlyRente (avs_calculator.dart:29, RAMD/échelle44 + anticipation/déferral ; gapFactor :52-67 dérivé de currentYears qui dépend d'arrivalAge).
Sites : minimal_profile_service.dart:92-98 (appel sans arrivalAge) ; mint_scene_rente_trouee.dart:47-51 (idem, commentaire :46 « sur carrière complète ») + :57 (LPP `grossAnnual*0.34/12`) ; cap_sequence_engine.dart:609-614 (`2520 * years / 44`, income-blind, +655 à +998 CHF/mois de surestimation).
Post-plan 06 : q_avs_lacunes_status + q_avs_arrival_year sont peuplés à l'onboarding — la donnée EXISTE désormais au moment où ces sites calculent.
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Plumb arrivalAge dans minimal_profile + déléguer cap_sequence</name>
  <files>apps/mobile/lib/services/minimal_profile_service.dart, apps/mobile/lib/services/cap_sequence_engine.dart, apps/mobile/test/services/financial_parity_test.dart</files>
  <read_first>
    - apps/mobile/lib/services/financial_core/avs_calculator.dart:29-110 (signature complète + gapFactor)
    - apps/mobile/lib/services/response_card_service.dart:760-770 (pattern de référence qui passe arrivalAge)
    - apps/mobile/lib/services/minimal_profile_service.dart:85-100 ; apps/mobile/lib/services/cap_sequence_engine.dart:605-620
    - Lignes matrice returning_swiss_gaps-1, §2 « Rente AVS »
  </read_first>
  <behavior>
    - Test (RED) : profil arrivalAge=43, 48 ans, RAMD 120000 → minimal_profile rente == AvsCalculator avec lacunes (~1260), plus 2520.
    - Parité : cap_sequence (years=44, RAMD=50000) == AvsCalculator (~1865), plus 2520 flat.
    - Profil sans lacunes → rente inchangée (pas de régression).
  </behavior>
  <action>minimal_profile_service:92-98 : transmettre arrivalAge/lacunes (désormais hydratés depuis q_avs_arrival_year, cf. coach_profile.dart:1511) à computeMonthlyRente, pattern identique à response_card_service:767. cap_sequence_engine:609-614 : `_estimateAvsMonthly` délègue à AvsCalculator (RAMD + années réelles), supprimer la formule plate `2520*years/44`. Groupe de parité « Rente AVS ».</action>
  <acceptance_criteria>
    - `grep -n "2520" apps/mobile/lib/services/cap_sequence_engine.dart` → 0 (hors commentaire justifié).
    - `cd apps/mobile && flutter test test/services/financial_parity_test.dart` exit 0 (oracle returning_swiss_gaps-1 re-run : 1260 pour arrivalAge=43).
  </acceptance_criteria>
  <verify>
    <automated>cd apps/mobile && flutter test test/services/financial_parity_test.dart && flutter analyze</automated>
  </verify>
  <done>returning_swiss_gaps-1 + §2 Rente AVS fermés.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Scène rente_trouee honnête + hypothèse jeune étiquetée</name>
  <files>apps/mobile/lib/screens/onboarding/mvp_wedge/scenes/mint_scene_rente_trouee.dart, apps/mobile/lib/l10n/app_*.arb</files>
  <read_first>
    - apps/mobile/lib/screens/onboarding/mvp_wedge/scenes/mint_scene_rente_trouee.dart:40-70
    - Lignes matrice returning_swiss_gaps-2, jeune_diplome-2
  </read_first>
  <behavior>
    - Widget test : profil avec lacunes (arrivée 43) → la fourchette de la scène intègre le gapFactor (composante AVS réduite vs carrière complète).
    - Profil 25 ans sans lacunes → le chiffre porte l'étiquette « hypothèse : carrière complète » (clé ARB, réutiliser le pattern d'étiquetage du plan 11).
    - La composante LPP de la scène vient de LppCalculator.projectToRetirement (plus de `* 0.34`).
  </behavior>
  <action>Re-câbler mint_scene_rente_trouee:47-51 sur computeMonthlyRente AVEC arrivalAge (la scène vit dans l'onboarding APRÈS la question lacunes du plan 06 — ordonner les scènes en conséquence dans le shell si nécessaire) ; :57 → LppCalculator.projectToRetirement. Étiquette « hypothèse : carrière complète » (ARB ×6) quand gapFactor==1.0 ET âge <30 (jeune_diplome-2). Écran modifié → panel design 4-personnes AVANT push. Device-proof : capture scène avec lacunes + capture jeune étiqueté, `.planning/_walker/illogism-fixes/w4/`.</action>
  <acceptance_criteria>
    - `grep -n "0\.34" apps/mobile/lib/screens/onboarding/mvp_wedge/scenes/mint_scene_rente_trouee.dart` → 0.
    - `cd apps/mobile && flutter test` exit 0 ; `accent_lint_fr` + `validate_arb_parity` OK.
    - Oracle returning_swiss_gaps-2 re-run : scène ≠ 2520 pour profil à lacunes ; captures citées.
    - Panel design exécuté, verdicts cités.
  </acceptance_criteria>
  <verify>
    <automated>cd apps/mobile && flutter test && flutter analyze && python3 tools/checks/accent_lint_fr.py</automated>
  </verify>
  <done>returning_swiss_gaps-2 + jeune_diplome-2 fermés.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries
| Boundary | Description |
|----------|-------------|
| moteurs AVS → onboarding hero | rente surestimée ×2 pour un profil à lacunes = intégrité |

## STRIDE Threat Register
| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-ILF-13-01 | Tampering (intégrité) | gapFactor ignoré | mitigate | plumbing arrivalAge + parité + étiquette hypothèse |
</threat_model>

<verification>
- `cd apps/mobile && flutter analyze && flutter test` + lints ; device-proof scène.
</verification>

<success_criteria>
- returning_swiss_gaps-1/-2, jeune_diplome-2, §2 Rente AVS fermés avec citations.
</success_criteria>

<output>
Create `.planning/phases/mint-illogism-fixes/mint-illogism-fixes-13-SUMMARY.md` + mise à jour VALIDATION.md Per-Task Map.
</output>
