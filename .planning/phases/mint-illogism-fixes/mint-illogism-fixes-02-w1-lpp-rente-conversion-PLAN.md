---
phase: mint-illogism-fixes
plan: 02
type: execute
wave: 2
depends_on: [mint-illogism-fixes-01]
files_modified:
  - apps/mobile/lib/screens/mariage_screen.dart
  - apps/mobile/lib/services/response_card_service.dart
  - apps/mobile/lib/screens/profile/financial_summary_screen.dart
  - apps/mobile/lib/services/independants_service.dart
  - apps/mobile/lib/services/cap_sequence_engine.dart
  - apps/mobile/lib/services/job_comparison_service.dart
  - apps/mobile/lib/services/minimal_profile_service.dart
  - apps/mobile/test/services/financial_parity_test.dart
autonomous: true
requirements:
  - MATRIX-salarie_swiss-4
  - MATRIX-independent_no_lpp-5
  - MATRIX-expat_us-4
  - MATRIX-frontalier-3
  - MATRIX-cadre_divorce_hypo-3
  - MATRIX-couple_acheteurs-3
  - MATRIX-returning_swiss_gaps-5
  - MATRIX-D4
must_haves:
  truths:
    - "Pour un même avoirLppTotal stocké, la rente LPP mensuelle affichée est IDENTIQUE sur tous les écrans (fin du spread 250-347 CHF/mois)."
    - "Tous les sites de rente passent par LppCalculator.adjustedConversionRate (la réduction retraite anticipée LPP art.13 al.2 s'applique partout)."
    - "L'impact mensuel d'un rachat LPP utilise la même base de taux de conversion que la rente (fin de la divergence 283 vs 242 CHF/mois pour 50000 de rachat)."
    - "Le commentaire périmé « conservative 5.4% » de response_card_service.dart:779 est corrigé."
  artifacts:
    - path: "apps/mobile/test/services/financial_parity_test.dart"
      provides: "Groupe « Rente LPP » : même avoir → même rente par tous les chemins d'appel"
      contains: "Rente LPP"
  key_links:
    - from: "apps/mobile/lib/screens/mariage_screen.dart"
      to: "apps/mobile/lib/services/financial_core/lpp_calculator.dart"
      via: "adjustedConversionRate au lieu de 0.068 hardcodé"
      pattern: "adjustedConversionRate"
    - from: "apps/mobile/lib/services/response_card_service.dart"
      to: "apps/mobile/lib/services/financial_core/lpp_calculator.dart"
      via: "adjustedConversionRate au lieu de lppTauxConversionSurobligDecimal direct"
      pattern: "adjustedConversionRate"
---

<objective>
W1 quantité #2 — Rente LPP mensuelle : UN taux de conversion par cas, via `LppCalculator.adjustedConversionRate` partout. Élimine le spread device-prouvé (D4 : 0.068 ET 0.058 rendus dans la même session) de 250-347 CHF/mois sur le même avoir stocké. Inclut la même correction pour l'impact mensuel d'un rachat LPP (même cause racine : base de taux ad-hoc).

Purpose: ferme 7 findings archétypes + §2 « Rente LPP » + §2 « Capacité rachat » (volet impact) + D4.
Output: 6+ sites délégués au canonique + groupe de parité « Rente LPP » + commentaire :779 corrigé.
</objective>

<execution_context>
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/workflows/execute-plan.md
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/phases/mint-illogism-fixes/mint-illogism-fixes-CONTEXT.md
@.planning/reports/MATRIX-illogismes-2026-06-09.md (§2 « Rente LPP » + « Capacité rachat LPP »)
@apps/mobile/lib/services/financial_core/lpp_calculator.dart

<interfaces>
Canonique : `LppCalculator.adjustedConversionRate({...})` (lpp_calculator.dart:43-52) — applique la réduction LPP art.13 al.2 (retraite anticipée) à partir du taux registry. Constantes : social_insurance.dart:74 lppTauxConversionMinDecimal=0.068 · :79 lppTauxConversionSurobligDecimal=0.058.
Sites divergents à re-câbler (matrice §2) :
- mariage_screen.dart:94 — `avoir * 0.068 / 12` hardcodé
- response_card_service.dart:776-780 — `avoir * lppTauxConversionSurobligDecimal / 12` + commentaire périmé :779 (« conservative 5.4% » vs 0.058 réel)
- screens/profile/financial_summary_screen.dart:127 — `avoir * profile.tauxConversion / 12`
- independants_service.dart:599 — `capitalLpp * _tauxConversion=0.068`
- cap_sequence_engine.dart:622 (`_estimateLppMonthly`) et :639-644 (`_estimateRachatImpact: rachat * profile.tauxConversion / 12`)
- job_comparison_service.dart:75 — `avoirVieillesse * tauxConversionSurobligatoire / 100`
- minimal_profile_service.dart:108-111 — branche complementaire 0.058 vs 0.068
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Groupe de parité « Rente LPP » RED puis re-câblage des sites de rente</name>
  <files>apps/mobile/test/services/financial_parity_test.dart, apps/mobile/lib/screens/mariage_screen.dart, apps/mobile/lib/services/response_card_service.dart, apps/mobile/lib/screens/profile/financial_summary_screen.dart, apps/mobile/lib/services/independants_service.dart, apps/mobile/lib/services/minimal_profile_service.dart</files>
  <read_first>
    - apps/mobile/lib/services/financial_core/lpp_calculator.dart:25-130 (adjustedConversionRate + son usage interne par projectToRetirement :118)
    - Les 7 sites cités dans interfaces (lire chaque hunk AVANT modification)
    - Lignes matrice : salarie_swiss-4, cadre_divorce_hypo-3 (incl. note commentaire :779), D4
  </read_first>
  <behavior>
    - Test (RED d'abord) : avoir stocké 300000, âge de retraite référence → la rente mensuelle calculée par chaque chemin public (mariage prefill, response card replacement, financial summary, independants, cap_sequence) est IDENTIQUE et == avoir × adjustedConversionRate(...) / 12.
    - Cas retraite anticipée : départ avant l'âge de référence → la réduction art.13 al.2 s'applique (rente strictement inférieure au cas référence).
  </behavior>
  <action>Ajouter le groupe « Rente LPP » à financial_parity_test.dart (RED, valeurs divergentes 1700 vs 1450 citées au commit). Puis re-câbler : chaque site calcule la rente via `LppCalculator.adjustedConversionRate` (passer l'âge de retraite du profil ; défaut = âge de référence). Supprimer `0.068` hardcodé (mariage_screen:94, independants_service _tauxConversion), remplacer l'usage direct de `lppTauxConversionSurobligDecimal` (response_card:776) et de `profile.tauxConversion` (financial_summary:127, cap_sequence:622) par l'appel canonique. Unifier la branche minimal_profile_service:108-111. Corriger le commentaire :779 pour refléter le taux réellement appliqué. Si un helper est utile, l'ajouter dans lpp_calculator.dart (ex. `static double monthlyRenteFromAvoir({required double avoir, ...})`) — PAS dans les services.</action>
  <acceptance_criteria>
    - `grep -n "0\.068" apps/mobile/lib/screens/mariage_screen.dart apps/mobile/lib/services/independants_service.dart` → 0 résultat hors commentaires.
    - `grep -rn "adjustedConversionRate\|monthlyRenteFromAvoir" apps/mobile/lib/screens/mariage_screen.dart apps/mobile/lib/services/response_card_service.dart apps/mobile/lib/screens/profile/financial_summary_screen.dart apps/mobile/lib/services/independants_service.dart` ≥ 4 sites.
    - `cd apps/mobile && flutter test test/services/financial_parity_test.dart` exit 0 (oracle matrice re-run : avoir 300000 → UNE rente, plus de spread 250 CHF/mois).
    - response_card_service.dart:779 ne contient plus « 5.4% ».
  </acceptance_criteria>
  <verify>
    <automated>cd apps/mobile && flutter test test/services/financial_parity_test.dart && flutter analyze</automated>
  </verify>
  <done>Tous les sites de rente délèguent au canonique ; parité verte ; ferme salarie_swiss-4, independent_no_lpp-5, expat_us-4, frontalier-3, cadre_divorce_hypo-3, couple_acheteurs-3, returning_swiss_gaps-5, D4 (citations exigées).</done>
</task>

<task type="auto">
  <name>Task 2: Unifier la base de taux de l'impact rachat LPP (même cause racine)</name>
  <files>apps/mobile/lib/services/cap_sequence_engine.dart, apps/mobile/lib/services/job_comparison_service.dart</files>
  <read_first>
    - apps/mobile/lib/services/cap_sequence_engine.dart:609-660 (_estimateLppMonthly + _estimateRachatImpact)
    - apps/mobile/lib/services/job_comparison_service.dart:60-90
    - Ligne matrice §2 « Capacité rachat LPP »
  </read_first>
  <action>`cap_sequence_engine._estimateRachatImpact` (:639-644) et `job_comparison_service.dart:75` calculent l'impact mensuel d'un rachat/avoir avec la MÊME base canonique `LppCalculator.adjustedConversionRate` que la Task 1 (fin de l'incohérence 0.068 vs surobligatoire). La capacité de rachat (rachatMaximum, champ profil lu du certificat) reste inchangée — seul l'IMPACT mensuel est re-câblé. Ajouter 1 cas au groupe « Rente LPP » : rachat 50000 → impact identique par les deux chemins.</action>
  <acceptance_criteria>
    - `grep -n "tauxConversion" apps/mobile/lib/services/cap_sequence_engine.dart apps/mobile/lib/services/job_comparison_service.dart` → plus d'usage direct pour le calcul d'impact (délégation visible).
    - `cd apps/mobile && flutter test test/services/financial_parity_test.dart test/services/` exit 0.
  </acceptance_criteria>
  <verify>
    <automated>cd apps/mobile && flutter test test/services/ && flutter analyze</automated>
  </verify>
  <done>Impact rachat sur base canonique unique ; ligne §2 « Capacité rachat » (volet impact divergent) fermée avec citation.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries
| Boundary | Description |
|----------|-------------|
| moteurs → surfaces UI | rente LPP fausse = décision financière utilisateur faussée (intégrité, LSFin) |

## STRIDE Threat Register
| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-ILF-02-01 | Tampering (intégrité) | sites de rente/rachat | mitigate | délégation adjustedConversionRate + parité au centime |
| T-ILF-02-02 | Repudiation | commentaire :779 trompeur | mitigate | commentaire aligné sur la valeur réelle |
</threat_model>

<verification>
- `cd apps/mobile && flutter analyze && flutter test` exit 0.
- Oracle matrice re-run : avoir 300000 → une seule rente sur tous les chemins.
</verification>

<success_criteria>
- 8 finding-IDs fermés avec citations ; zéro taux de conversion inline restant hors financial_core et constants registry.
</success_criteria>

<output>
Create `.planning/phases/mint-illogism-fixes/mint-illogism-fixes-02-SUMMARY.md` + mise à jour VALIDATION.md Per-Task Map.
</output>
