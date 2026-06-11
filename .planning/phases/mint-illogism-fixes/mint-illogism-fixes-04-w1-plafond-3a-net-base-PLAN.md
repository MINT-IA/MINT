---
phase: mint-illogism-fixes
plan: 04
type: execute
wave: 4
depends_on: [mint-illogism-fixes-03]
files_modified:
  - apps/mobile/lib/services/financial_core/tax_calculator.dart
  - apps/mobile/lib/services/minimal_profile_service.dart
  - apps/mobile/test/services/financial_parity_test.dart
autonomous: true
requirements:
  - MATRIX-independent_no_lpp-1
  - MATRIX-independent_no_lpp-2
must_haves:
  truths:
    - "Le plafond 3a d'un indépendant sans LPP = 20% du revenu professionnel NET, plafonné 36288 (OPP3 art.7 al.2) — sur TOUS les chemins."
    - "Pour net pro 86400 : plafond = 17280 partout (plus jamais 21600 calculé sur le brut 108000)."
    - "Contrôles négatifs intacts : salarié avec LPP → 7258 inchangé (salarie_swiss-6, jeune_diplome-4, cadre_divorce_hypo-6)."
  artifacts:
    - path: "apps/mobile/lib/services/financial_core/tax_calculator.dart"
      provides: "Branche hasLpp=false sur base NET professionnelle"
      contains: "netProfessionalIncome"
    - path: "apps/mobile/test/services/financial_parity_test.dart"
      provides: "Groupe « Plafond 3a indépendant » : tax_calculator == independants_service"
      contains: "Plafond 3a"
  key_links:
    - from: "apps/mobile/lib/services/minimal_profile_service.dart"
      to: "apps/mobile/lib/services/financial_core/tax_calculator.dart"
      via: "passage du revenu net professionnel à estimate3aTaxImpact"
      pattern: "netProfessionalIncome"
---

<objective>
W1 quantité #4 — Plafond 3a indépendant : base = revenu professionnel NET (OPP3 art.7 al.2) partout. `tax_calculator.dart:548` et `minimal_profile_service.dart:135-152` calculent aujourd'hui sur le BRUT (+25% d'écart, finding WRONG) ; `independants_service.dart:412` (net) est la référence.

Purpose: ferme independent_no_lpp-1 (WRONG) et independent_no_lpp-2 (DIVERGENT — deux moteurs, deux bases).
Output: branche hasLpp=false sur base nette + parité tax_calculator/independants_service.
</objective>

<execution_context>
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/workflows/execute-plan.md
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/reports/MATRIX-illogismes-2026-06-09.md (independent_no_lpp-1/-2)

<interfaces>
Signature actuelle (vérifiée) : `TaxCalculator.estimate3aTaxImpact({required double grossAnnualSalary, required String canton, bool isMarried = false, int children = 0, bool hasLpp = true, int contributionMonths = 12, double? contribution, double? actualMarginalRate})` — branche plafond : `hasLpp ? reg('pillar3a.max_with_lpp', pilier3aPlafondAvecLpp) : (grossAnnualSalary * pilier3aTauxRevenuSansLpp).clamp(0.0, pilier3aPlafondSansLpp)`.
Constantes : social_insurance.dart:351 pilier3aPlafondAvecLpp=7258 · :354 pilier3aPlafondSansLpp=36288 · :357 pilier3aTauxRevenuSansLpp=0.20.
Référence correcte : independants_service.dart:412 `min(revenuNet * 0.20, 36288)`.
Schéma : `selfEmployedNetIncome` existe (SOT §1).
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Base NET dans estimate3aTaxImpact + plumbing minimal_profile_service</name>
  <files>apps/mobile/lib/services/financial_core/tax_calculator.dart, apps/mobile/lib/services/minimal_profile_service.dart, apps/mobile/test/services/financial_parity_test.dart</files>
  <read_first>
    - apps/mobile/lib/services/financial_core/tax_calculator.dart:525-600 (estimate3aTaxImpact complet + Pillar3aTaxImpactEstimate)
    - apps/mobile/lib/services/independants_service.dart:400-420 (référence net)
    - apps/mobile/lib/services/minimal_profile_service.dart:135-152 (appelant + fallback :149 gross*0.20)
    - Lignes matrice independent_no_lpp-1/-2
  </read_first>
  <behavior>
    - Test (RED) : net pro 86400, brut 108000, hasLpp=false → annualCeiling == 17280 via estimate3aTaxImpact ET via independants_service.calculate3aIndependant (parité inter-moteurs).
    - Contrôle négatif : hasLpp=true → annualCeiling == 7258 inchangé.
    - Net absent (null) : le plafond sans-LPP est calculé sur un net dérivé (NetIncomeBreakdown) — JAMAIS sur le brut nu.
  </behavior>
  <action>Ajouter `double? netProfessionalIncome` à `estimate3aTaxImpact` ; la branche `hasLpp == false` calcule `((netProfessionalIncome ?? netDerive) * pilier3aTauxRevenuSansLpp).clamp(0.0, pilier3aPlafondSansLpp)` où `netDerive` vient de NetIncomeBreakdown.compute (base nette canonique du plan 03) — plus jamais `grossAnnualSalary` direct. Mettre à jour minimal_profile_service:135-152 : passer `selfEmployedNetIncome` (ou le net dérivé) et corriger le fallback :149 (`grossSalary*0.20` → net*0.20). NE PAS toucher independants_service:412 (référence). Groupe de parité « Plafond 3a indépendant ».</action>
  <acceptance_criteria>
    - `grep -n "grossAnnualSalary \* pilier3aTauxRevenuSansLpp" apps/mobile/lib/services/financial_core/tax_calculator.dart` → 0 résultat.
    - `cd apps/mobile && flutter test test/services/financial_parity_test.dart` exit 0 (oracle re-run : 86400 net → 17280 sur les deux moteurs ; 7258 inchangé pour hasLpp=true).
    - `cd apps/mobile && flutter analyze && flutter test test/services/` exit 0 (les ~9300 tests des sites touchés mis à jour, pas contournés).
  </acceptance_criteria>
  <verify>
    <automated>cd apps/mobile && flutter test test/services/financial_parity_test.dart && flutter analyze</automated>
  </verify>
  <done>Plafond indépendant sur base nette partout ; ferme independent_no_lpp-1 et independent_no_lpp-2 ; contrôles négatifs (7258) prouvés intacts.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries
| Boundary | Description |
|----------|-------------|
| moteur fiscal → UI | plafond 3a surévalué de +25% = sur-promesse de déduction fiscale (risque LSFin) |

## STRIDE Threat Register
| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-ILF-04-01 | Tampering (intégrité) | branche plafond sans-LPP | mitigate | base nette + parité inter-moteurs + contrôle négatif 7258 |
</threat_model>

<verification>
- `cd apps/mobile && flutter analyze && flutter test` exit 0.
</verification>

<success_criteria>
- independent_no_lpp-1/-2 fermés avec citation ; aucun chemin restant calculant le plafond indépendant sur le brut.
</success_criteria>

<output>
Create `.planning/phases/mint-illogism-fixes/mint-illogism-fixes-04-SUMMARY.md` + mise à jour VALIDATION.md Per-Task Map.
</output>
