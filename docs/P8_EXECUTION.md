# P8 — Digital Twin: Execution Plan (Prod-Ready)

> **Version**: 5.1 (post-audit, all corrections integrated)
> **Date**: 2026-03-03
> **Status**: VALIDATED — Ready for execution
> **Prerequisite**: Read `CLAUDE.md` + `visions/` + `decisions/ADR-20260223-unified-financial-engine.md`

---

## WORKFLOW — COMMENT EXÉCUTER CE PLAN

### Principe: Zéro loop manuelle

Chaque phase est **auto-suffisante**. L'agent codeur ET l'agent auditeur lisent CE document.
Pas de copier-coller d'un agent à l'autre. Pas de re-prompting.

### Séquence par phase

```
1. CODER:   Lire P8_EXECUTION.md § Phase N
2. CODER:   Exécuter les tâches listées
3. CODER:   Exécuter la GATE CHECKLIST § Phase N
4. CODER:   Ne committer QUE si TOUTES les gates passent
5. CODER:   Committer avec message "P8-N: <description>"
6. AUDITOR: Lire P8_EXECUTION.md § Phase N GATE CHECKLIST
7. AUDITOR: Exécuter CHAQUE commande grep/test listée
8. AUDITOR: Reporter PASS/FAIL par gate (pas de prose, pas d'opinion)
9. SI FAIL:  Le rapport d'audit EST la spec de fix (pas besoin de reformuler)
10. CODER:  Lire le rapport FAIL, fixer, re-run gates, re-commit
```

### Règle d'or

> **Si ce n'est pas dans la GATE CHECKLIST, ce n'est pas un bug.**
> **Si c'est dans la GATE CHECKLIST et ça FAIL, c'est un blocker.**

---

## CONSTANTES — SOURCES EXISTANTES (ZÉRO HARDCODING)

Toute valeur financière DOIT venir d'une de ces sources. **Aucun magic number autorisé.**

| Besoin | Source | Fichier | Ligne |
|--------|--------|---------|-------|
| Charges sociales employé (7.35%) | `cotisationsSalarieTotal` | `constants/social_insurance.dart` | 201 |
| AVS employé (5.3%) | `avsCotisationSalarie` | `constants/social_insurance.dart` | 83 |
| AI employé (0.7%) | `aiCotisationSalarie` | `constants/social_insurance.dart` | 138 |
| APG employé (0.25%) | `apgCotisationSalarie` | `constants/social_insurance.dart` | 151 |
| AC employé (1.1%) | `acCotisationSalarie` | `constants/social_insurance.dart` | 171 |
| Bonification LPP par âge | `getLppBonificationRate(age)` | `constants/social_insurance.dart` | 60-66 |
| Déduction coordination LPP | `lppDeductionCoordination` (26'460) | `constants/social_insurance.dart` | 24 |
| Salaire coordonné min | `lppSalaireCoordMin` (3'780) | `constants/social_insurance.dart` | 27 |
| Salaire coordonné max | `lppSalaireCoordMax` (64'260) | `constants/social_insurance.dart` | 30 |
| Seuil d'entrée LPP | `lppSeuilEntree` (22'680) | `constants/social_insurance.dart` | 21 |
| Taux impôt retrait capital | `tauxImpotRetraitCapital[canton]` | `constants/social_insurance.dart` | — |
| Impôt revenu par canton | `FiscalService.estimateTax()` | `services/fiscal_service.dart` | 129 |
| Taux marginal centralisé | `RetirementTaxCalculator.estimateMarginalRate()` | `services/financial_core/tax_calculator.dart` | 75 |
| Impôt mensuel revenu | `RetirementTaxCalculator.estimateMonthlyIncomeTax()` | `services/financial_core/tax_calculator.dart` | 101 |
| Barèmes fiscaux détaillés | `TaxScalesLoader.getBrackets()` | `services/tax_scales_loader.dart` | 96 |
| Taux effectifs 26 cantons | `FiscalService.effectiveRates100kSingle` | `services/fiscal_service.dart` | 15-45 |
| Confidence scoring | `ConfidenceScorer.score()` | `services/financial_core/confidence_scorer.dart` | — |
| ProfileDataSource enum | `{estimated, userInput, certificate}` | `models/coach_profile.dart` | 23-27 |

---

## FAITS VÉRIFIÉS (référence pour agents)

Ces facts ont été audités par 5 rounds d'audit croisés (12 audits total). Ne PAS les remettre en question.

| Fait | Preuve |
|------|--------|
| `PlanTrackingService` **EXISTE** (175L, 5 tests) | Glob=2 fichiers, Grep=6 refs, `evaluate()` utilisé retirement_dashboard_screen.dart:241 |
| ArbitrageEngine = **5** méthodes publiques | compareRenteVsCapital, compareAllocationAnnuelle, compareLocationVsPropriete, compareRachatVsMarche, compareCalendrierRetraits |
| `compareMixedStrategy()` N'EXISTE PAS | Le mixte est un sous-cas interne de compareRenteVsCapital:76 |
| Route `/coach/dashboard` → RetirementDashboardScreen | app.dart:**174** |
| `identical()` lifecycle bug | retirement_dashboard_screen.dart:**127** |
| `dataSources` = **getter calculé** (127 lignes, 3 tests) | `get dataSources {` à coach_profile.dart:**986-1112**. Logique déterministe. |
| `SmartDefaultIndicator` existe | widgets/precision/smart_default_indicator.dart (249L) |
| `initialProjectionSnapshot` N'EXISTE PAS | À créer (Phase 2) |
| `ProjectionResult.fromJson()` N'EXISTE PAS | Seul toJson() existe (forecaster_service.dart:175). À créer (Phase 2/5) |
| `_estimateMarginalRate()` dupliqué dans **4 fichiers** | minimal_profile:152, financial_report:618, precision:730, retirement_dashboard:306 |
| `getLppBonificationRate()` = taux TOTAL | Employé paie ~50% → diviser par 2 pour déduction salariale |
| `FiscalService.chargeTotale` = impôt SEUL | Pas de charges sociales dedans (fiscal_service.dart:142-160) |
| `CoachDashboardScreen` = dead code | 0 imports production, route pointe vers RetirementDashboardScreen |
| `* 0.87` = 31 occurrences dans 13 fichiers | grep -rn "0\.87" apps/mobile/lib/ --include="*.dart" |
| `ProfileDataSource` enum | `{certificate, userInput, estimated}` — coach_profile.dart:22-26 |
| `TaxScalesLoader.getBrackets()` + tax_scales.json (67 KB) | 26 cantons, brackets réels, 28 tests |
| `cotisationsSalarieTotal` = 0.0735 (7.35%) | social_insurance.dart:201 — AVS 5.3% + AI 0.7% + APG 0.25% + AC 1.1% |
| `lppDeductionCoordination` = 26'460 | social_insurance.dart:24 — LPP art. 8 |

---

## PHASE 1 — TAX FOUNDATION

### Objectif
Remplacer TOUS les `* 0.87` par un calcul dynamique décomposé. Centraliser `_estimateMarginalRate()`.

### Tâche 1.1 — Créer `NetIncomeBreakdown` dans tax_calculator.dart

**Fichier**: `apps/mobile/lib/services/financial_core/tax_calculator.dart`

Ajouter AVANT la classe `RetirementTaxCalculator` :

```dart
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/services/fiscal_service.dart';

/// Décomposition du revenu net — remplace * 0.87.
///
/// Deux niveaux de "net":
/// - netPayslip = brut - charges sociales - LPP employé (ce qui arrive sur le compte)
/// - disposableIncome = netPayslip - impôt sur le revenu (ce qu'il reste à vivre)
///
/// ZÉRO valeur hardcodée. Toutes les constantes viennent de:
/// - social_insurance.dart (cotisationsSalarieTotal, getLppBonificationRate, lppDeductionCoordination)
/// - fiscal_service.dart (estimateTax)
class NetIncomeBreakdown {
  final double grossSalary;
  final double socialCharges;
  final double lppEmployee;
  final double incomeTaxEstimate;
  final String canton;
  final int age;

  const NetIncomeBreakdown({
    required this.grossSalary,
    required this.socialCharges,
    required this.lppEmployee,
    required this.incomeTaxEstimate,
    required this.canton,
    required this.age,
  });

  /// Salaire net (fiche de paie) = brut - charges sociales - LPP employé.
  double get netPayslip => grossSalary - socialCharges - lppEmployee;

  /// Revenu disponible = net fiche de paie - impôt sur le revenu.
  double get disposableIncome => netPayslip - incomeTaxEstimate;

  /// Ratio net/brut (remplace 0.87).
  double get netRatio => grossSalary > 0 ? netPayslip / grossSalary : 0;

  /// Ratio disponible/brut.
  double get disposableRatio => grossSalary > 0 ? disposableIncome / grossSalary : 0;

  /// Factory: calcul dynamique à partir de brut, canton, âge.
  ///
  /// Formules:
  /// - socialCharges = brut × cotisationsSalarieTotal (7.35%)
  /// - salaireCoord = clamp(brut - lppDeductionCoordination, lppSalaireCoordMin, lppSalaireCoordMax)
  /// - lppEmployee = salaireCoord × getLppBonificationRate(age) / 2
  ///   (LPP art. 66: employeur paie min 50%, employé ~50%)
  /// - incomeTax = FiscalService.estimateTax(brut, canton).chargeTotale
  factory NetIncomeBreakdown.compute({
    required double grossSalary,
    required String canton,
    required int age,
    String etatCivil = 'celibataire',
    int nombreEnfants = 0,
  }) {
    // 1. Charges sociales (AVS + AI + APG + AC) — hors LPP
    final socialCharges = grossSalary * cotisationsSalarieTotal;

    // 2. LPP employé (~50% de la bonification totale sur salaire coordonné)
    double lppEmployee = 0;
    if (grossSalary >= lppSeuilEntree && age >= 25 && age <= 65) {
      final salaireCoord = (grossSalary - lppDeductionCoordination)
          .clamp(lppSalaireCoordMin, lppSalaireCoordMax);
      final totalBonif = getLppBonificationRate(age);
      lppEmployee = salaireCoord * totalBonif / 2; // ~50% part employé (LPP art. 66)
    }

    // 3. Impôt sur le revenu (via FiscalService, 26 cantons)
    final taxResult = FiscalService.estimateTax(
      revenuBrut: grossSalary,
      canton: canton,
      etatCivil: etatCivil,
      nombreEnfants: nombreEnfants,
    );
    final incomeTax = (taxResult['chargeTotale'] as double?) ?? 0;

    return NetIncomeBreakdown(
      grossSalary: grossSalary,
      socialCharges: socialCharges,
      lppEmployee: lppEmployee,
      incomeTaxEstimate: incomeTax,
      canton: canton,
      age: age,
    );
  }

  Map<String, dynamic> toJson() => {
        'grossSalary': grossSalary,
        'socialCharges': socialCharges,
        'lppEmployee': lppEmployee,
        'incomeTaxEstimate': incomeTaxEstimate,
        'netPayslip': netPayslip,
        'disposableIncome': disposableIncome,
        'netRatio': netRatio,
        'canton': canton,
        'age': age,
      };
}
```

### Tâche 1.2 — Remplacer ~31× `* 0.87` dans les 13 fichiers

Pour CHAQUE occurrence de `* 0.87` (ou `*0.87`) dans les fichiers production.

**Pattern de remplacement** :
```dart
// AVANT:
final net = brut * 0.87;

// APRÈS:
final breakdown = NetIncomeBreakdown.compute(
  grossSalary: brut,
  canton: canton, // ou profile.canton
  age: age,       // ou profile.age
);
final net = breakdown.netPayslip; // ou .disposableIncome selon contexte
```

**Mapping contextuel précis** (du plan v5 validé) :

| Fichier | Nb occ. | Context | Remplacer par | Justification |
|---------|---------|---------|---------------|---------------|
| `forecaster_service.dart` | 4× | Replacement rate denominator | `breakdown.netPayslip` | Compare avant-impôt vs rente avant-impôt |
| `retirement_projection_service.dart` | 6× | Pre-retirement income, transition | `breakdown.netPayslip` | Budget/transition |
| `coach_profile.dart` | 2× | resteAVivreMensuel, toBudgetInputs | `breakdown.netPayslip` | What's on the payslip |
| `coach_profile_provider.dart` | 1× | Wizard answer persistence | `breakdown.netPayslip` | Stored for profile |
| `budget_inputs.dart` | 2× | Household net for budget | `breakdown.netPayslip` | Budget calculation |
| `retirement_dashboard_screen.dart` | 1× | Dashboard display | `breakdown.netPayslip` | Current income display |
| `retirement_screen.dart` | 2× | Retirement income display | `breakdown.netPayslip` | Legacy screen |
| `financial_report_service.dart` | 3× | Report, dont inverse /0.87 | `breakdown + estimateBrutFromNet()` | Full report |
| `financial_fitness_service.dart` | 1× | Fitness score input | `breakdown.netPayslip` | Score calculation |
| `bayesian_enricher.dart` | 1× | Expense estimation | `breakdown.netPayslip` | Prior estimation |
| `housing_cost_calculator.dart` | 2× | Expense floor | `breakdown.netPayslip` | Housing affordability |
| `early_retirement_comparison.dart` | 1× | Early retirement comparison | `breakdown.netPayslip` | Comparison |

**Règle de choix** :
- Replacement rate denominator → `netPayslip` (compare avant-impôt vs rente avant-impôt — pommes avec pommes)
- Budget / reste à vivre → `netPayslip`
- Chiffre choc (comparaison inter-canton) → `disposableIncome`
- Expense estimation → `netPayslip * 0.85` (comme MinimalProfileService actuel)
- Dans le doute → `netPayslip` (plus conservateur)

**Import à ajouter dans chaque fichier** :
```dart
import 'package:mint_mobile/services/financial_core/tax_calculator.dart';
```

### Tâche 1.3 — Migrer les 4 `_estimateMarginalRate()` privées

| Fichier | Ligne définition | Implémentation actuelle | Action |
|---------|-----------------|------------------------|--------|
| `services/minimal_profile_service.dart` | 152 | Utilise FiscalService (la meilleure) | Migrer vers `RetirementTaxCalculator.estimateMarginalRate()` |
| `services/financial_report_service.dart` | 618 | Brackets hardcodés, ignore canton | Idem |
| `services/precision/precision_service.dart` | 730 | Brackets hardcodés + multiplicateurs cantonaux | Idem |
| `screens/coach/retirement_dashboard_screen.dart` | 306 | Brackets simplifiés, ignore canton | Idem |

**Les 4 donnent des résultats différents pour le même input.** Toutes doivent migrer vers `RetirementTaxCalculator.estimateMarginalRate()` (tax_calculator.dart:75).

**Import déjà présent** dans tax_calculator.dart. Chaque fichier doit importer :
```dart
import 'package:mint_mobile/services/financial_core/tax_calculator.dart';
```

### Tâche 1.4 — Archiver CoachDashboardScreen

**Fichier** : `apps/mobile/lib/screens/coach/coach_dashboard_screen.dart`
**Action** : Déplacer vers `apps/mobile/lib/screens/coach/archive/coach_dashboard_screen.dart`

### Tâche 1.5 — Tests Phase 1

Créer `apps/mobile/test/financial_core/net_income_breakdown_test.dart` :

```dart
// Tests requis (minimum 8):
// 1. Julien 50 ans, 100k, ZH → socialCharges ≈ 7350, lppEmployee ≈ 5516
// 2. Lauren 45 ans, 60k, ZH → vérifier salaireCoord correct
// 3. Salaire < seuil LPP (20k) → lppEmployee = 0
// 4. Âge < 25 → lppEmployee = 0
// 5. Canton ZG (low tax) → incomeTax < ZH
// 6. Canton GE (high tax) → incomeTax > ZH
// 7. netPayslip = gross - social - lpp (arithmétique)
// 8. disposableIncome = netPayslip - tax (arithmétique)
// 9. netRatio pour 100k ZH ≈ 0.87 (± 0.02) — régression vs ancien * 0.87
// 10. Couple marié 2 enfants → incomeTax réduit
```

Golden values (calculées) :
- Julien (50, 100k, ZH) :
  - socialCharges = 100000 × 0.0735 = 7350
  - salaireCoord = max(3780, min(64260, 100000 - 26460)) = 73540 → clampé OK
  - lppEmployee = 73540 × 0.15 / 2 = 5515.50
  - netPayslip = 100000 - 7350 - 5515.50 = 87134.50
  - incomeTaxEstimate ≈ 12900 (ZH ~12.9%)
  - disposableIncome ≈ 74234.50

### PHASE 1 — GATE CHECKLIST

Chaque gate est une commande shell. **TOUTES doivent retourner le résultat attendu.**

```bash
# === GATE 1.1: Zéro * 0.87 en production ===
# Attendu: 0 lignes (hors tests, archive, commentaires)
grep -rn "0\.87" apps/mobile/lib/ --include="*.dart" | grep -v test | grep -v archive | grep -v "\/\/" | grep -v "0\.873" | grep -v "0\.879" | wc -l
# PASS si = 0

# === GATE 1.2: NetIncomeBreakdown existe ===
grep -rn "class NetIncomeBreakdown" apps/mobile/lib/ --include="*.dart" | wc -l
# PASS si = 1

# === GATE 1.3: NetIncomeBreakdown.compute() utilise les constantes ===
grep -n "cotisationsSalarieTotal\|getLppBonificationRate\|lppDeductionCoordination\|lppSeuilEntree\|FiscalService.estimateTax" apps/mobile/lib/services/financial_core/tax_calculator.dart | wc -l
# PASS si >= 5

# === GATE 1.4: Zéro _estimateMarginalRate privée en production ===
grep -rn "_estimateMarginalRate" apps/mobile/lib/ --include="*.dart" | grep -v test | grep -v archive | wc -l
# PASS si = 0

# === GATE 1.5: CoachDashboardScreen archivé ===
ls apps/mobile/lib/screens/coach/coach_dashboard_screen.dart 2>/dev/null | wc -l
# PASS si = 0 (fichier n'existe plus dans son emplacement original)

# === GATE 1.6: Aucun import de CoachDashboardScreen ===
grep -rn "coach_dashboard_screen" apps/mobile/lib/ --include="*.dart" | grep -v archive | wc -l
# PASS si = 0

# === GATE 1.7: Tests existent et passent ===
ls apps/mobile/test/financial_core/net_income_breakdown_test.dart 2>/dev/null | wc -l
# PASS si = 1
cd apps/mobile && flutter test test/financial_core/net_income_breakdown_test.dart
# PASS si tous verts

# === GATE 1.8: Aucune régression ===
cd apps/mobile && flutter analyze 2>&1 | grep -c "error"
# PASS si = 0
cd apps/mobile && flutter test
# PASS si tous verts

# === GATE 1.9: Zéro magic number fiscal ===
# Vérifie qu'aucun nouveau 0.13, 0.85, 0.87, 0.25 fiscal n'a été introduit
git diff --cached -- apps/mobile/lib/ | grep "^+" | grep -E "\b0\.(87|85|13|25)\b" | grep -v "test\|archive\|\/\/" | wc -l
# PASS si = 0
```

---

## PHASE 2 — FLOW UNIFIÉ (Onboarding → JIT → Top3)

### Objectif
Transformer le SmartOnboarding 2 pages en flow 5 étapes : Stress → 3Q → ChiffreChoc → JIT → Top3.

### Tâche 2.1 — Étendre SmartOnboarding

**Fichier** : `apps/mobile/lib/screens/onboarding/smart_onboarding_screen.dart`

Le PageView actuel (lignes 193-215) a 2 pages. Ajouter 3 pages :
- Page 3 : `StepJitExplanation` — mini-explication du chiffre choc (SI... ALORS...)
- Page 4 : `StepTopActions` — Top 3 actions (coaching_service.dart tips triées par priority)
- Page 5 : `StepNextStep` — CTA vers dashboard ou enrichissement

**Dépendances** :
- `ChiffreChocSelector` (déjà existant) : `lib/services/chiffre_choc_selector.dart`
- `CoachingService` (13 triggers, déjà existant) : `lib/services/coaching_service.dart`
- `NetIncomeBreakdown` (Phase 1) pour projections chiffre choc

### Tâche 2.2 — Mapping stress → tips

Ajouter à `CoachingTip` un getter basé sur `.category` (déjà existant) :

```dart
// coaching_service.dart — PAS une nouvelle propriété, juste un helper
static List<CoachingTip> filterByStressType(List<CoachingTip> tips, String stressType) {
  const stressToCategories = {
    'stress_retraite': ['retraite', 'prevoyance'],
    'stress_fiscal': ['fiscalite'],
    'stress_budget': ['budget'],
    'stress_general': ['retraite', 'fiscalite', 'budget', 'prevoyance'],
  };
  final categories = stressToCategories[stressType] ?? ['retraite', 'fiscalite', 'budget'];
  return tips.where((t) => categories.contains(t.category)).toList();
}
```

### Tâche 2.3 — Analytics events structurés

Créer `apps/mobile/lib/services/analytics_events.dart` :
```dart
/// Noms d'événements analytics — single source of truth.
/// Remplace les string literals inline dans analytics_service.dart.
class AnalyticsEvents {
  AnalyticsEvents._();
  static const onboardingStarted = 'onboarding_started';
  static const onboardingStressSelected = 'onboarding_stress_selected';
  static const onboardingCompleted = 'onboarding_completed';
  static const chiffreChocViewed = 'chiffre_choc_viewed';
  static const chiffreChocShared = 'chiffre_choc_shared';
  static const jitExplanationViewed = 'jit_explanation_viewed';
  static const topActionTapped = 'top_action_tapped';
  static const enrichmentStarted = 'enrichment_started';
  static const enrichmentCompleted = 'enrichment_completed';
  // ... etc
}
```

### Tâche 2.4 — Snapshot initial

Ajouter à `CoachProfile` :
```dart
// Dans coach_profile.dart, champ + constructeur + copyWith
final Map<String, dynamic>? initialProjectionSnapshot;
```

Ajouter à `ProjectionResult` (forecaster_service.dart) :
```dart
factory ProjectionResult.fromJson(Map<String, dynamic> json) { ... }
```

### PHASE 2 — GATE CHECKLIST

```bash
# === GATE 2.1: Onboarding = 5 pages ===
grep -c "Step" apps/mobile/lib/screens/onboarding/smart_onboarding_screen.dart | head -1
# Compter les pages dans le PageView — PASS si >= 5 steps

# === GATE 2.2: filterByStressType existe ===
grep -rn "filterByStressType" apps/mobile/lib/ --include="*.dart" | wc -l
# PASS si >= 1

# === GATE 2.3: analytics_events.dart créé ===
ls apps/mobile/lib/services/analytics_events.dart 2>/dev/null | wc -l
# PASS si = 1

# === GATE 2.4: initialProjectionSnapshot dans CoachProfile ===
grep -n "initialProjectionSnapshot" apps/mobile/lib/models/coach_profile.dart | wc -l
# PASS si >= 2 (champ + constructeur)

# === GATE 2.5: ProjectionResult.fromJson existe ===
grep -n "fromJson" apps/mobile/lib/services/forecaster_service.dart | wc -l
# PASS si >= 1

# === GATE 2.6: Aucune régression ===
cd apps/mobile && flutter analyze 2>&1 | grep -c "error"
# PASS si = 0
cd apps/mobile && flutter test
# PASS si tous verts
```

---

## PHASE 3 — DATA BLOCKS + CONFIDENCE V2

### Objectif
Ajouter les composantes manquantes au ConfidenceScorer (objectifRetraite, ménage).
Ajouter `scoreAsBlocs()`. Routes data-block/*.

### Tâche 3.1 — Enrichir ConfidenceScorer

**Fichier** : `apps/mobile/lib/services/financial_core/confidence_scorer.dart`

Ajouter 2 composantes :
- `objectifRetraite` (poids: 10) — scoré si le profil a un âge de retraite souhaité (non-default != 65)
- `compositionMenage` (poids: 15) — scoré si le profil a le statut familial + données partenaire

**Redistribution des poids** (du plan v5 final validé) :

| Composante | V1 (actuel) | V2 (nouveau) | Delta | Source légale |
|------------|-------------|--------------|-------|---------------|
| Salaire | 15 | 12 | -3 | — |
| Âge + Canton | 10 | 8 | -2 | — |
| Archetype | 5 | 5 | = | — |
| **Objectif retraite** | — | **10** | **+10** | LAVS art. 21 (âge légal) |
| **Ménage (couple)** | — | **15** | **+15** | LPP art. 19 (rente survivant) |
| LPP avoir réel | 20 | 15 | -5 | LPP art. 15 |
| Taux conversion | 10 | 5 | -5 | LPP art. 14 |
| AVS extrait | 15 | 10 | -5 | LAVS art. 29 |
| 3a soldes | 10 | 8 | -2 | OPP3 art. 7 |
| Patrimoine | 10 | 7 | -3 | — |
| Foreign pension | 5 | 5 | = | — |
| **Total** | **100** | **100** | **0** | |

**Logique objectifRetraite** (10 pts) : `effectiveRetirementAge != 65` (non-default) → +10. Sinon → +3, prompt "Fixe un objectif retraite".

**Logique ménage** (15 pts) :
- Célibataire → +15 (non applicable)
- Marié sans données partenaire → +0, prompt "Ajoute les infos de ton·ta partenaire"
- Partenaire partiel (revenu OU âge) → +8
- Partenaire complet (revenu + âge) → +15

**Total doit rester = 100.** Invariant testé.

### Tâche 3.2 — Ajouter `scoreAsBlocs()`

```dart
/// Retourne le score décomposé par bloc (pour affichage UI).
Map<String, BlockScore> scoreAsBlocs(CoachProfile profile) {
  // Retourne: { 'revenu': BlockScore(score, max, status), 'lpp': ..., ... }
}

class BlockScore {
  final double score;
  final double maxScore;
  final String status; // 'complete', 'partial', 'missing'
  const BlockScore({required this.score, required this.maxScore, required this.status});
}
```

### Tâche 3.3 — Routes data-block/*

**Fichier** : `apps/mobile/lib/app.dart`

Ajouter les routes pour les blocs de données (écrans d'enrichissement par bloc).

### PHASE 3 — GATE CHECKLIST

```bash
# === GATE 3.1: Nouvelles composantes dans ConfidenceScorer ===
grep -n "objectifRetraite\|compositionMenage" apps/mobile/lib/services/financial_core/confidence_scorer.dart | wc -l
# PASS si >= 2

# === GATE 3.2: scoreAsBlocs existe ===
grep -n "scoreAsBlocs" apps/mobile/lib/services/financial_core/confidence_scorer.dart | wc -l
# PASS si >= 1

# === GATE 3.3: LPP poids >= 18 ===
# Vérification manuelle dans confidence_scorer.dart — chercher le poids LPP
grep -A2 "lpp\|LPP" apps/mobile/lib/services/financial_core/confidence_scorer.dart | grep -E "[0-9]+"
# PASS si poids LPP >= 18

# === GATE 3.4: Total poids = 100 ===
# L'agent doit vérifier que la somme des poids = 100 dans le code
# Test unitaire requis pour valider

# === GATE 3.5: Routes data-block existent ===
grep -c "data-block" apps/mobile/lib/app.dart
# PASS si >= 1

# === GATE 3.6: Aucune régression ===
cd apps/mobile && flutter analyze 2>&1 | grep -c "error"
cd apps/mobile && flutter test
# PASS si tous verts
```

---

## PHASE 4 — ARBITRAGE AUTO-FILL

### Objectif
Connecter les 5 simulateurs d'arbitrage au CoachProfile (auto-fill). Remplacer les confidenceScore hardcodés.

### Tâche 4.1 — Auto-fill des 5 simulateurs

**5 méthodes** (PAS 6 — `compareMixedStrategy` n'existe pas) :

| Méthode | Fichier écran | Champs à auto-fill |
|---------|--------------|-------------------|
| `compareRenteVsCapital` | rente_vs_capital_screen.dart (639L) | age, capitalLpp, tauxConversion, canton |
| `compareAllocationAnnuelle` | allocation_annuelle_screen.dart (740L) | age, revenu, canton, cotisation3a |
| `compareLocationVsPropriete` | (dans arbitrage_engine) | revenu, loyer, apport |
| `compareRachatVsMarche` | (dans arbitrage_engine) | capitalLpp, potentielRachat, canton |
| `compareCalendrierRetraits` | calendrier_retraits_screen.dart (996L) | age, capitaux3a[], capitalLpp |

Chaque écran doit :
1. Accepter un `CoachProfile?` optionnel via GoRouter extra
2. Si présent, pré-remplir les champs avec `profile.xxx`
3. Afficher `SmartDefaultIndicator` pour les valeurs estimées (`dataSources[field] == ProfileDataSource.estimated`)
4. Rester 100% fonctionnel sans profil (standalone mode)

### Tâche 4.2 — Confidence dynamique

Remplacer les 5 hardcoded `confidenceScore` :

```dart
// AVANT (dans arbitrage_engine.dart):
confidenceScore: 65.0,

// APRÈS:
confidenceScore: _computeArbitrageConfidence(inputs, profileDataSources),
```

Logique :
```dart
static double _computeArbitrageConfidence(
  Map<String, dynamic> inputs,
  Map<String, ProfileDataSource>? sources,
) {
  if (sources == null) return 50.0; // mode standalone
  int known = 0, total = 0;
  for (final key in inputs.keys) {
    total++;
    if (sources[key] == ProfileDataSource.certificate) known += 2;
    else if (sources[key] == ProfileDataSource.userInput) known += 1;
  }
  return (known / (total * 2) * 100).clamp(30, 95);
}
```

### Tâche 4.3 — Bandeau "Résultat indicatif"

Si confidence < 70 → afficher un `Banner` Material en haut du résultat :
"Résultat indicatif — précise tes données pour un résultat plus fiable."

### PHASE 4 — GATE CHECKLIST

```bash
# === GATE 4.1: 5 simulateurs acceptent CoachProfile ===
for screen in rente_vs_capital_screen allocation_annuelle_screen calendrier_retraits_screen; do
  grep -l "CoachProfile" apps/mobile/lib/screens/*/${screen}.dart 2>/dev/null || echo "MISSING: $screen"
done
# PASS si aucun MISSING

# === GATE 4.2: Zéro confidenceScore hardcodé dans arbitrage_engine ===
grep -n "confidenceScore:" apps/mobile/lib/services/financial_core/arbitrage_engine.dart | grep -E "[0-9]{2}\.[0-9]" | wc -l
# PASS si = 0 (tous dynamiques)

# === GATE 4.3: _computeArbitrageConfidence existe ===
grep -n "_computeArbitrageConfidence" apps/mobile/lib/services/financial_core/arbitrage_engine.dart | wc -l
# PASS si >= 1

# === GATE 4.4: SmartDefaultIndicator utilisé dans les écrans ===
grep -rl "SmartDefaultIndicator" apps/mobile/lib/screens/ --include="*.dart" | wc -l
# PASS si >= 3

# === GATE 4.5: Bandeau indicatif implémenté ===
grep -rn "indicatif\|Résultat indicatif" apps/mobile/lib/ --include="*.dart" | wc -l
# PASS si >= 1

# === GATE 4.6: Aucune régression ===
cd apps/mobile && flutter analyze 2>&1 | grep -c "error"
cd apps/mobile && flutter test
```

---

## PHASE 5 — DASHBOARD ASSEMBLY

### Objectif
Ajouter `compoundProjectedImpact()` au PlanTrackingService existant (175L, 5 tests).
Assembler le dashboard unifié. Fixer le lifecycle bug `identical()`. Nouveaux widgets.

### Tâche 5.1 — Ajouter compoundProjectedImpact() à PlanTrackingService

**Fichier existant** : `apps/mobile/lib/services/plan_tracking_service.dart` (175L, 5 tests)

Le service EXISTE avec `evaluate()` utilisé dans retirement_dashboard_screen.dart:241.
Ajouter ~20 lignes :

```dart
/// FV annuity: gapMensuel × ((1+r)^n - 1) / r
/// Educational: 2% real return (conservative).
/// CRITIQUE: Pas de magic number — 0.02 = conservative real return documenté.
static double compoundProjectedImpact({
  required PlanStatus status,
  required int monthsToRetirement,
  double annualReturn = 0.02, // 2% real return (conservative estimate)
}) {
  if (monthsToRetirement <= 0 || status.nextActions.isEmpty) return 0;
  final monthlyRate = annualReturn / 12;
  final n = monthsToRetirement.toDouble();
  // FV annuity formula: PMT × ((1+r)^n - 1) / r
  final monthlyGap = status.score > 0 ? (status.completedActions * 100.0) : 0;
  if (monthlyRate == 0) return monthlyGap * n;
  return monthlyGap * ((pow(1 + monthlyRate, n) - 1) / monthlyRate);
}
```

### Tâche 5.2 — Fixer le lifecycle bug `identical()`

**Fichier** : `apps/mobile/lib/screens/coach/retirement_dashboard_screen.dart`
**Ligne** : **127**

```dart
// AVANT (ligne 127):
if (identical(_profile, newProfile)) return;

// APRÈS:
if (_profile != null && _profile == newProfile) return;
```

Ceci requiert que `CoachProfile` implémente `operator ==` et `hashCode`.
Vérifier si c'est déjà le cas (equatable ou manual override).

### Tâche 5.3 — Nouveaux widgets dashboard (4)

| Fichier | ~Lignes | Description |
|---------|---------|-------------|
| `widgets/coach/patrimoine_snapshot_card.dart` | ~180 | Total patrimoine + stacked bar 5 segments |
| `widgets/coach/fri_radar_chart.dart` | ~300 | CustomPainter spider L/F/R/S (0-25) |
| `widgets/coach/trajectory_comparison_card.dart` | ~280 | Day-1 (gris pointillé) vs current (primary) + delta |
| `widgets/coach/plan_reality_card.dart` | ~250 | Adherence badge + barres + impact composé |

### Tâche 5.4 — Wiring dans RetirementDashboardScreen

State A (>=70%) : + PatrimoineSnapshotCard + ConfidenceBlocksBar (Phase 3).
Cockpit expanded : + TrajectoryComparisonCard + FriRadarChart + PlanRealityCard.

### Tâche 5.5 — ForecasterService fromJson() factories (~40L)

Ajouter `ProjectionResult.fromJson()`, `ProjectionScenario.fromJson()`, `ProjectionPoint.fromJson()`.

### Tâche 5.6 — Snapshot persistence

Connecter `initialProjectionSnapshot` (Phase 2) :
- Au premier chargement du dashboard, si `profile.initialProjectionSnapshot == null`, sauvegarder la projection courante
- Permettre la comparaison "avant/après" dans le dashboard (TrajectoryComparisonCard)

### PHASE 5 — GATE CHECKLIST

```bash
# === GATE 5.1: compoundProjectedImpact existe ===
grep -n "compoundProjectedImpact" apps/mobile/lib/services/plan_tracking_service.dart | wc -l
# PASS si >= 1

# === GATE 5.2: compoundProjectedImpact testé ===
grep -rn "compoundProjectedImpact" apps/mobile/test/ --include="*.dart" | wc -l
# PASS si >= 1

# === GATE 5.3: identical() remplacé ===
grep -n "identical(_profile" apps/mobile/lib/screens/coach/retirement_dashboard_screen.dart | wc -l
# PASS si = 0

# === GATE 5.4: == utilisé à la place ===
grep -n "_profile == newProfile\|_profile != null" apps/mobile/lib/screens/coach/retirement_dashboard_screen.dart | wc -l
# PASS si >= 1

# === GATE 5.5: 4 nouveaux widgets créés ===
ls apps/mobile/lib/widgets/coach/patrimoine_snapshot_card.dart \
   apps/mobile/lib/widgets/coach/fri_radar_chart.dart \
   apps/mobile/lib/widgets/coach/trajectory_comparison_card.dart \
   apps/mobile/lib/widgets/coach/plan_reality_card.dart 2>/dev/null | wc -l
# PASS si = 4

# === GATE 5.6: ForecasterService fromJson existe ===
grep -n "fromJson" apps/mobile/lib/services/forecaster_service.dart | wc -l
# PASS si >= 3 (ProjectionResult + Scenario + Point)

# === GATE 5.7: Smoke test tab 0 ===
# PatrimoineSnapshot + FRI Radar rendus sans crash
grep -rn "PatrimoineSnapshotCard\|FriRadarChart" apps/mobile/lib/screens/coach/retirement_dashboard_screen.dart | wc -l
# PASS si >= 2

# === GATE 5.8: Aucune régression ===
cd apps/mobile && flutter analyze 2>&1 | grep -c "error"
cd apps/mobile && flutter test
```

---

## GATE FINALE — TOUTES PHASES

```bash
# === MEGA-GATE 1: Zéro * 0.87 en production ===
grep -rn "0\.87" apps/mobile/lib/ --include="*.dart" | grep -v test | grep -v archive | grep -v "//" | wc -l
# PASS si = 0

# === MEGA-GATE 2: Zéro _estimateMarginalRate privée ===
grep -rn "_estimateMarginalRate" apps/mobile/lib/ --include="*.dart" | grep -v test | grep -v archive | wc -l
# PASS si = 0

# === MEGA-GATE 3: PlanTrackingService existe et testé ===
grep -rn "class PlanTrackingService" apps/mobile/lib/ --include="*.dart" | wc -l
# PASS si = 1

# === MEGA-GATE 4: ArbitrageEngine confidence dynamique ===
grep -n "confidenceScore:" apps/mobile/lib/services/financial_core/arbitrage_engine.dart | grep -E "[0-9]{2}\.[0-9]" | wc -l
# PASS si = 0

# === MEGA-GATE 5: Flutter analyze clean ===
cd apps/mobile && flutter analyze 2>&1 | grep -c "error"
# PASS si = 0

# === MEGA-GATE 6: Flutter test green ===
cd apps/mobile && flutter test
# PASS si tous verts

# === MEGA-GATE 7: Backend stable ===
cd services/backend && python3 -m pytest tests/ -q
# PASS si tous verts

# === MEGA-GATE 8: NetIncomeBreakdown utilise UNIQUEMENT constantes existantes ===
grep -n "0\.\|const \|= [0-9]" apps/mobile/lib/services/financial_core/tax_calculator.dart | grep -v import | grep -v "bracket\|Multiplier\|0\.0\b\|\/\/" | head -20
# Audit visuel: aucun magic number
```

---

## MATRICE DE RISQUES (P × I)

| Phase | Risque | P | I | P×I | Mitigation | Test Gate |
|-------|--------|---|---|-----|------------|-----------|
| P1 | "Net" incohérent / double-comptage | 3 | 5 | 15 | NetIncomeBreakdown avec décomposition traçable, 2 niveaux | Net monotone ZG>ZH>GE + Golden test Julien |
| P1 | Certificate dead-end persiste | 4 | 4 | 16 | Fix identical() → deep check + test widget scan→valeurs changent | Widget test: inject before/after reload |
| P2 | Onboarding >60s ou "4e question" | 2 | 3 | 6 | StressSelector = tap intention, pas formulaire. Mesure temps | E2E: fresh install <60s + count écrans = 3Q |
| P2 | Analytics payloads CHF exact | 3 | 4 | 12 | Wrapper constants + helpers bands. Grep lint | Test: aucun event ne prend CHF exact |
| P3 | Deux vérités confiance | 4 | 4 | 16 | Single source ConfidenceScorer, UI n'invente rien | Invariant: somme=100, prompts non vides si <70 |
| P4 | Auto-fill ambigu (known vs assumed) | 4 | 5 | 20 | Provenance ProfileDataSource existant, déterministe | Widget test: certificate→vert, estimated→gris |
| P4 | Bandeau compliance absent | 3 | 5 | 15 | Confidence dynamique (profil-aware) + CTA | Test: <70 → visible, ≥70 → caché |
| P5 | Widgets non actionnables | 2 | 3 | 6 | Timebox + smoke + plan_action events | Smoke: tab 0 rend cartes + compoundProjectedImpact |

**Top 3 risques** : P4 auto-fill ambiguïté (P×I=20), P1/P3 confiance split (16), P1 net incohérent (15).

---

## COMPARAISON INTER-CANTONS (référence Golden Test)

Julien (100k, 50 ans, célibataire) — le `* 0.87` donnait 87k partout :

| Canton | netPayslip | disposable | vs * 0.87 (87k payslip) |
|--------|-----------|-----------|------------------------|
| ZG | ~91'900 | ~83'700 | +5.6% |
| ZH | ~87'100 | ~74'200 | +0.15% (quasi identique par hasard) |
| GE | ~83'700 | ~68'300 | -3.8% |

Le `* 0.87` tombait juste pour ZH/100k/50ans par coïncidence, mais était systématiquement faux pour les autres cantons, âges et situations familiales.

---

## INSTRUCTIONS POUR L'AGENT AUDITEUR

Tu lis CE document. Tu exécutes les commandes de la GATE CHECKLIST de la phase demandée.
Pour chaque gate, tu rapportes :

```
GATE X.Y: [PASS|FAIL]
  Commande: <la commande exécutée>
  Résultat: <output>
  Attendu: <ce qui était attendu>
  [Si FAIL] Fix requis: <description précise du fix>
```

**Tu ne donnes PAS d'opinion.** Tu ne "suggères" PAS d'améliorations.
Tu rapportes PASS ou FAIL. C'est tout.

Le rapport FAIL EST la spec de fix. L'agent codeur le lit et corrige.

---

## INSTRUCTIONS POUR L'AGENT CODEUR

Tu lis CE document § Phase N. Tu exécutes les tâches dans l'ordre.
AVANT de committer, tu exécutes toi-même la GATE CHECKLIST.
Si une gate FAIL, tu fixes AVANT de committer.

**Tu ne "améliores" PAS le code au-delà de ce qui est demandé.**
**Tu ne refactors PAS du code hors scope.**
**Tu ne changes PAS les poids/constantes sauf si explicitement listé.**

---

## ESTIMATION

```
PHASE 1 — TAX FOUNDATION (2 jours)          ← BLOQUANT pour tout
  │  NetIncomeBreakdown + ~30× remplacement + cert lifecycle fix + archive dead code
  │
  v
PHASE 2 — FLOW UNIFIÉ (2.5 jours)           ← Time-to-Value
  │  stress(tap)→3Q→chiffre choc→JIT→Top3 + analytics + day-1 snapshot
  │
  ├──────────────────────────────┐
  v                              v
PHASE 3 — DATA BLOCKS           PHASE 4 — ARBITRAGE AUTO-FILL
+ CONFIDENCE V2                  + COMPLIANCE (provenance wiring)
(2.5 jours)                     (3 jours)
  │                              │
  └──────────┬───────────────────┘
             v
PHASE 5 — DASHBOARD ASSEMBLY (2.5 jours, timeboxée)
```

| Phase | Durée | Dépendances | Parallélisable |
|-------|-------|-------------|----------------|
| Phase 1 | 2j | Aucune | Non (bloquant) |
| Phase 2 | 2.5j | Phase 1 | Non |
| Phase 3 | 2.5j | Phase 1 | Oui (// Phase 4) |
| Phase 4 | 3j | Phase 1 + 3 | Oui (// Phase 3) |
| Phase 5 | 2.5j | Phase 1 + 2 + 3 + 4 | Non |
| **Critical path** | **~10j** | 1 → 2 → 4 → 5 | |
