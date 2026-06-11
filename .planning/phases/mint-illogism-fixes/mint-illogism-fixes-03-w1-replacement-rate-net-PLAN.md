---
phase: mint-illogism-fixes
plan: 03
type: execute
wave: 3
depends_on: [mint-illogism-fixes-02]
files_modified:
  - apps/mobile/lib/services/financial_core/replacement_rate.dart
  - apps/mobile/lib/services/minimal_profile_service.dart
  - apps/mobile/lib/services/budget_living_engine.dart
  - apps/mobile/lib/services/response_card_service.dart
  - apps/mobile/lib/services/cap_sequence_engine.dart
  - apps/mobile/lib/services/premier_eclairage_selector.dart
  - apps/mobile/lib/services/coach/coach_profile_seeds.dart
  - apps/mobile/test/services/financial_parity_test.dart
autonomous: true
requirements:
  - MATRIX-salarie_swiss-5
  - MATRIX-independent_no_lpp-6
  - MATRIX-expat_us-5
  - MATRIX-frontalier-4
  - MATRIX-cadre_divorce_hypo-4
  - MATRIX-jeune_diplome-3
  - MATRIX-couple_acheteurs-4
  - MATRIX-returning_swiss_gaps-6
  - MATRIX-D3
must_haves:
  truths:
    - "Le taux de remplacement a UNE définition app-wide : revenu retraite mensuel / revenu NET mensuel courant (sens économique, lock CONTEXT W1)."
    - "Le même profil voit le MÊME taux de remplacement sur onboarding, response card et budget (fin de l'écart 10-20 pts, D3 : 63% vs 46.5% même session)."
    - "budget_living_engine ne mélange plus numérateur net / dénominateur brut dans une même formule."
    - "Le NET mensuel vient de NetIncomeBreakdown.compute partout — plus de ratios plats 0.75/0.78 (fin du spread 300 CHF/mois sur 120k brut)."
    - "Le revenu retraite total a UNE composition : AVS + LPP (le service de dette n'est plus soustrait par un seul des moteurs)."
  artifacts:
    - path: "apps/mobile/lib/services/financial_core/replacement_rate.dart"
      provides: "Définition canonique unique du taux de remplacement (L1, pure, offline)"
      exports: ["ReplacementRate"]
    - path: "apps/mobile/test/services/financial_parity_test.dart"
      provides: "Groupes « Taux de remplacement » + « Base nette »"
      contains: "Taux de remplacement"
  key_links:
    - from: "apps/mobile/lib/services/minimal_profile_service.dart"
      to: "apps/mobile/lib/services/financial_core/replacement_rate.dart"
      via: "ReplacementRate.percent au lieu de /grossMonthlySalary"
      pattern: "ReplacementRate\\."
    - from: "apps/mobile/lib/services/minimal_profile_service.dart"
      to: "NetIncomeBreakdown"
      via: "NetIncomeBreakdown.compute au lieu de *0.75"
      pattern: "NetIncomeBreakdown"
---

<objective>
W1 quantité #3 — Taux de remplacement : UNE définition (dénominateur NET courant, lock CONTEXT) via un helper canonique financial_core, et UNE base nette canonique (`NetIncomeBreakdown.compute`) qui remplace les ratios plats 0.75/0.78. Ferme aussi la divergence de composition du revenu retraite total (§2 « Retraite projetée » : soustraction de dette dans un seul moteur).

Purpose: ferme la classe « replacement rate divergent » sur les 8 archétypes + §2 « Taux de remplacement » + §2 « Marge libre » + §2 « Retraite projetée » + D3.
Output: financial_core/replacement_rate.dart + 6 services re-câblés + groupes de parité.
</objective>

<execution_context>
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/workflows/execute-plan.md
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/phases/mint-illogism-fixes/mint-illogism-fixes-CONTEXT.md
@.planning/reports/MATRIX-illogismes-2026-06-09.md (§2 « Taux de remplacement », « Marge libre », « Retraite projetée »)

<interfaces>
Sites divergents (matrice) :
- minimal_profile_service.dart:127-130 — `totalMonthlyRetirement = max(0, avs + lpp - debtService)` puis `/ grossMonthlySalary` (BRUT + soustraction dette)
- response_card_service.dart:782-790 — `avs + lpp` (sans dette) `/ NetIncomeBreakdown.monthlyNetPayslip` (NET — référence pour le dénominateur)
- budget_living_engine.dart:253-254 — `retirement.monthlyNet / grossMonthlySalary` (MIXTE incohérent — bug dans une seule formule)
Ratios plats à remplacer par NetIncomeBreakdown.compute (§2 « Marge libre ») :
- cap_sequence_engine.dart:653 (`* 0.78`) · minimal_profile_service.dart:229 (`* 0.75 / 12`) · premier_eclairage_selector.dart:377 (`* 0.75`) · coach/coach_profile_seeds.dart:133 (`?? gross * 0.78`)
Canonique net existant : NetIncomeBreakdown.compute (canton+âge aware), déjà utilisé par budget_living_engine:153 et cross_pillar_calculator:396.
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: ReplacementRate canonique + définition unique (dénominateur NET, numérateur AVS+LPP)</name>
  <files>apps/mobile/lib/services/financial_core/replacement_rate.dart, apps/mobile/lib/services/minimal_profile_service.dart, apps/mobile/lib/services/budget_living_engine.dart, apps/mobile/lib/services/response_card_service.dart, apps/mobile/test/services/financial_parity_test.dart</files>
  <read_first>
    - apps/mobile/lib/services/response_card_service.dart:782-790 (chemin NET de référence + NetIncomeBreakdown usage exact)
    - apps/mobile/lib/services/minimal_profile_service.dart:120-135
    - apps/mobile/lib/services/budget_living_engine.dart:245-260
    - Lignes matrice : salarie_swiss-5, cadre_divorce_hypo-4, D3
  </read_first>
  <behavior>
    - Test (RED) : même profil (brut 102000, net via NetIncomeBreakdown, revenu retraite identique) → taux de remplacement IDENTIQUE par les 3 chemins publics (minimal_profile, response_card, budget_living).
    - Le numérateur est AVS+LPP sans soustraction de dette sur tous les chemins (la dette reste une donnée budget, pas un revenu retraite).
  </behavior>
  <action>Créer `apps/mobile/lib/services/financial_core/replacement_rate.dart` : `class ReplacementRate { static double percent({required double totalMonthlyRetirement, required double netMonthlyIncome}) }` (pure, clamp ≥0, doc : dénominateur = NET courant per CONTEXT lock ; golden Julien/Lauren à confirmer post-merge, non-bloquant). Re-câbler : minimal_profile_service:128-130 (dénominateur NET via NetIncomeBreakdown.compute ; retirer `- debtService` du total retraite :127 — décision discretion : composition canonique = AVS+LPP comme response_card et retirement_projection_service) ; budget_living_engine:253-254 (corriger la formule mixte) ; response_card_service:789-790 (déléguer au helper — comportement inchangé, c'est la référence). Groupe de parité « Taux de remplacement » dans financial_parity_test.dart.</action>
  <acceptance_criteria>
    - `apps/mobile/lib/services/financial_core/replacement_rate.dart` existe, exporté, ≥1 doc-comment citant la définition NET.
    - `grep -n "grossMonthlySalary" apps/mobile/lib/services/budget_living_engine.dart` → plus utilisé comme dénominateur de remplacement (:253-254).
    - `grep -rn "ReplacementRate\." apps/mobile/lib/services/ | wc -l` ≥ 3 sites.
    - `cd apps/mobile && flutter test test/services/financial_parity_test.dart` exit 0 (oracle D3 re-run : un seul pourcentage par profil).
  </acceptance_criteria>
  <verify>
    <automated>cd apps/mobile && flutter test test/services/financial_parity_test.dart && flutter analyze</automated>
  </verify>
  <done>Définition unique en place ; ferme salarie_swiss-5, independent_no_lpp-6, expat_us-5, frontalier-4, cadre_divorce_hypo-4, jeune_diplome-3, couple_acheteurs-4, returning_swiss_gaps-6, D3, §2-retraite-composition.</done>
</task>

<task type="auto">
  <name>Task 2: Base nette canonique — tuer les ratios plats 0.75/0.78</name>
  <files>apps/mobile/lib/services/cap_sequence_engine.dart, apps/mobile/lib/services/premier_eclairage_selector.dart, apps/mobile/lib/services/coach/coach_profile_seeds.dart, apps/mobile/lib/services/minimal_profile_service.dart, apps/mobile/test/services/financial_parity_test.dart</files>
  <read_first>
    - Les 4 sites à ratios plats (interfaces) + l'usage canonique NetIncomeBreakdown.compute dans budget_living_engine.dart:150-160
    - Ligne matrice §2 « Marge libre mensuelle »
  </read_first>
  <action>Remplacer chaque ratio plat par `NetIncomeBreakdown.compute` (canton+âge du profil) : cap_sequence_engine:653 (`* 0.78`), minimal_profile_service:229 (`* 0.75 / 12`), premier_eclairage_selector:377 (`* 0.75`), coach_profile_seeds:133 (fallback `* 0.78` — garder le fallback uniquement si canton inconnu, alors le DOCUMENTER comme estimation et préférer NetIncomeBreakdown avec canton par défaut). Groupe de parité « Base nette » : brut 120000 + canton fixe → net identique par tous les chemins (fin du spread 300 CHF/mois).</action>
  <acceptance_criteria>
    - `grep -rn "0\.75\|0\.78" apps/mobile/lib/services/cap_sequence_engine.dart apps/mobile/lib/services/minimal_profile_service.dart apps/mobile/lib/services/premier_eclairage_selector.dart apps/mobile/lib/services/coach/coach_profile_seeds.dart` → 0 usage comme proxy de net (hors commentaires/autres sens).
    - `cd apps/mobile && flutter test test/services/` exit 0.
  </acceptance_criteria>
  <verify>
    <automated>cd apps/mobile && flutter test test/services/ && flutter analyze</automated>
  </verify>
  <done>Base nette unique via NetIncomeBreakdown ; ligne §2 « Marge libre » fermée avec citation.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries
| Boundary | Description |
|----------|-------------|
| moteurs → surfaces UI | taux de remplacement contradictoire = perte de confiance + conseil implicite faussé (LSFin) |

## STRIDE Threat Register
| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-ILF-03-01 | Tampering (intégrité) | replacement rate / base nette | mitigate | helper canonique financial_core + parité 3 chemins |
| T-ILF-03-02 | Information disclosure | aucun nouveau flux PII | accept | calculs purs, pas de nouvelle donnée collectée |
</threat_model>

<verification>
- `cd apps/mobile && flutter analyze && flutter test` exit 0.
- Oracle D3 re-run sur sim (walkthrough W1 au plan 05).
</verification>

<success_criteria>
- 11 lignes matrice fermées (8 archétypes RR + §2×3) avec citations ; définition NET documentée dans le code.
</success_criteria>

<output>
Create `.planning/phases/mint-illogism-fixes/mint-illogism-fixes-03-SUMMARY.md` + mise à jour VALIDATION.md Per-Task Map.
</output>
