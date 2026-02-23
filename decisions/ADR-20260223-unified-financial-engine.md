# ADR-20260223 — Unified Financial Engine

**Status**: Implemented
**Date**: 2026-02-23
**Authors**: Julien + Claude (dream team audit)
**Supersedes**: Partial content in ADR-20260223-archetype-driven-retirement.md

### Implementation Status (2026-02-23)

| Phase | Status | Commit |
|-------|--------|--------|
| 0a. Data plumbing (spouse AVS, residence_permit) | DONE (was already mapped) | `d7cf2c4` |
| 0b. Fix _estimateLppAvoir (arrivalAge) | DONE | `bfa8e86` |
| 1a-d. Extract financial_core (AVS, LPP, Tax, Confidence) | DONE (29 tests) | `e914dfe` |
| 2. Migrate RetirementProjectionService | DONE (zero behavior change) | `6e8f86e` |
| 3. Migrate ForecasterService | DONE (bonifications, capital tax, RAMD AVS) | `ab7653d` |
| 4. Confidence Score UI | DONE (banner + enrichment prompts) | `cb5c898` |
| 5. Cleanup duplicates (lpp_deep, rente_vs_capital, expat, financial_report) | DONE | `656e620` |
| Fix: isMarried on 3a capital withdrawal tax | DONE | `7b392ff` |

**All services now import `financial_core/` — zero duplicate calculation logic remains.**

---

## Contexte

### Audit exhaustif (2026-02-23)

Deux moteurs de calcul independants produisaient des resultats **divergents** pour le meme profil :

| Aspect | RetirementProjectionService | ForecasterService | Status |
|--------|---------------------------|-------------------|--------|
| LPP bonifications (7/10/15/18%) | OUI | ~~NON~~ → OUI via `LppCalculator.projectOneMonth()` | FIXED |
| Capital withdrawal tax (LIFD art. 38) | OUI | ~~NON~~ → OUI via `RetirementTaxCalculator` | FIXED |
| 3a capital tax | OUI | ~~NON~~ → OUI via `RetirementTaxCalculator` | FIXED |
| AVS lacunes user | OUI | ~~NON~~ → OUI via `AvsCalculator` | FIXED |
| arrivalAge pour expats | OUI | ~~NON~~ → OUI via `AvsCalculator` | FIXED |
| Married-only couple cap | OUI | ~~NON~~ → OUI via `AvsCalculator.computeCouple()` | FIXED |
| RAMD-based AVS rente | OUI | ~~NON~~ → OUI via `AvsCalculator.renteFromRAMD()` | FIXED |
| Couple phases (retraite decalee) | OUI | NON | FUTURE |
| Scenarios (prudent/base/optimiste) | NON | OUI | By design |
| Monthly projection points | NON | OUI | By design |
| "Et si..." sliders | NON | OUI | By design |

**Status (2026-02-23)** : Both engines now use `financial_core/` for all shared calculations.
The remaining differences (couple phases, scenarios, monthly points) are **by design** — each engine serves a different purpose.

### Donnees collectees mais gaspillees (CORRIGE 2026-02-23)

| Donnee | Collectee dans | Mappee dans CoachProfile | Utilisee | Status |
|--------|---------------|--------------------------|----------|--------|
| `q_spouse_avs_lacunes_status` | Wizard V2 | OUI → conjoint.prevoyance.lacunesAVS | OUI (both engines) | FIXED |
| `q_spouse_avs_arrival_year` | Wizard V2 | OUI → conjoint.arrivalAge | OUI (both engines) | FIXED |
| `q_spouse_avs_years_abroad` | Wizard V2 | OUI → conjoint.prevoyance.lacunesAVS | OUI (both engines) | FIXED |
| `residence_permit` | Mini step 1 | OUI → residencePermit | Mapped, used by archetype | FIXED |
| `partner_employment_status` | Mini step 2 | OUI | Read by conjoint LPP estimation | FIXED |
| Conjoint LPP avoir | Estimated from salary + arrivalAge | OUI | OUI (both engines) | ESTIMATED |

---

## Decision

### Architecture choisie : Option C — Shared Core + Adapters

```
lib/services/financial_core/
  ├── avs_calculator.dart        — Calcul AVS (anticipation, ajournement, couple cap)
  ├── lpp_calculator.dart        — Projection LPP (bonifications, rachat, conversion)
  ├── three_a_calculator.dart    — Projection 3a (plafonds, rendement, tax retrait)
  ├── tax_calculator.dart        — Impot retrait capital + impot revenu retraite
  ├── patrimoine_calculator.dart — Epargne libre + investissements (SWR 4%)
  ├── confidence_scorer.dart     — Score de confiance par archetype
  └── financial_core.dart        — Barrel export

lib/services/
  ├── retirement_projection_service.dart  — Adapter retraite (phases, charts)
  ├── forecaster_service.dart             — Adapter dashboard (monthly points, scenarios)
  └── (both import financial_core/)
```

### Pourquoi Option C et pas les autres

| Option | Description | Verdict |
|--------|-------------|---------|
| A. Shared functions library | Fonctions pures partagees, services restent separes | Bon mais ne resout pas la divergence structurelle |
| B. Service unique monolithique | Merger tout en 1 fichier avec output adapters | Trop gros (~2000 lignes), hard to test, regression |
| **C. Shared Core + Adapters** | Core commun, adapters legers par ecran | **CHOISI** — modular, testable, zero duplication |
| D. Full domain-driven | Strategy pattern, factories, interfaces | Over-engineered pour une startup a 2 personnes |

### Principes

1. **Zero duplication** : chaque formule existe UNE seule fois dans le core
2. **Pure functions** : toutes les fonctions du core sont statiques et deterministes
3. **Core = source de verite** : les adapters ne font que formater, jamais recalculer
4. **Testable isolement** : chaque calculator a ses propres tests unitaires
5. **Migration incrementale** : un calculator a la fois, pas de big bang

---

## Plan d'implementation

### Phase 0 — Data plumbing (pre-requis)

Corriger le pipeline de donnees avant de toucher au calcul.

#### 0a. CoachProfile — mapper les donnees manquantes

```dart
// Dans fromWizardAnswers(), AJOUTER :

// === Conjoint prevoyance (actuellement jamais mappe) ===
PrevoyanceProfile? conjointPrevoyance;
if (partnerIncome != null && partnerIncome > 0) {
  final spouseAvsStatus = answers['q_spouse_avs_lacunes_status'] as String?;
  int spouseAvsGaps = 0;
  int? spouseArrivalAge;
  switch (spouseAvsStatus) {
    case 'arrived_late':
      final spouseArrivalYear = _parseInt(answers['q_spouse_avs_arrival_year']);
      final spouseBirthYear = _parseInt(answers['q_partner_birth_year']);
      if (spouseArrivalYear != null && spouseBirthYear != null) {
        spouseArrivalAge = spouseArrivalYear - spouseBirthYear;
        spouseAvsGaps = (spouseArrivalYear - (spouseBirthYear + 21)).clamp(0, 44);
      }
    case 'lived_abroad':
      spouseAvsGaps = _parseInt(answers['q_spouse_avs_years_abroad']) ?? 0;
    case 'unknown':
      spouseAvsGaps = 2;
    default:
      spouseAvsGaps = 0;
  }

  // Estimer LPP conjoint avec arrivalAge
  final conjAge = _parseInt(answers['q_partner_birth_year']) != null
      ? DateTime.now().year - _parseInt(answers['q_partner_birth_year'])!
      : 35;
  final conjEmployment = answers['q_partner_employment_status'] as String?;
  final conjHasLpp = conjEmployment != 'independant' && conjEmployment != 'inactive';
  final conjLppEstimate = conjHasLpp
      ? _estimateLppAvoir(conjAge, partnerBrut, startAge: spouseArrivalAge ?? 25)
      : 0.0;

  conjointPrevoyance = PrevoyanceProfile(
    lacunesAVS: spouseAvsGaps > 0 ? spouseAvsGaps : null,
    avoirLppTotal: conjLppEstimate,
  );

  conjoint = ConjointProfile(
    firstName: answers['q_partner_firstname'] as String?,
    birthYear: _parseInt(answers['q_partner_birth_year']),
    salaireBrutMensuel: partnerBrut,
    employmentStatus: conjEmployment,
    prevoyance: conjointPrevoyance,
  );
}

// === residence_permit dans CoachProfile ===
// Ajouter champ : final String? residencePermit;
// Mapper : residencePermit: answers['q_residence_permit'] as String?,
```

#### 0b. _estimateLppAvoir — corriger pour arrivalAge

```dart
// AVANT :
static double _estimateLppAvoir(int age, double salaireBrutMensuel) {
  for (int a = 25; a < age && a < 65; a++) { ... }
}

// APRES :
static double _estimateLppAvoir(int age, double salaireBrutMensuel, {int startAge = 25}) {
  final effectiveStart = max(25, startAge);
  for (int a = effectiveStart; a < age && a < 65; a++) { ... }
}
```

### Phase 1 — Extraire le Financial Core

Un calculator a la fois, en commencant par le plus simple.

#### 1a. AvsCalculator

```dart
// lib/services/financial_core/avs_calculator.dart

class AvsCalculator {
  AvsCalculator._();

  /// Calcule la rente AVS mensuelle pour un individu.
  /// Source : LAVS art. 21-29, art. 34, art. 40
  static double computeMonthlyRente({
    required int currentAge,
    required int retirementAge,
    int lacunes = 0,
    int? anneesContribuees,
  }) {
    // Formule unique (actuellement dans RetirementProjectionService._computeAvs
    // ET ForecasterService._estimateAvsCouple — DIVERGENTS)
  }

  /// Calcule les rentes AVS couple avec plafonnement 150%.
  /// Source : LAVS art. 35
  static AvsResult computeCouple({
    required AvsInput user,
    required AvsInput? conjoint,
    required bool isCouple,
  }) { ... }
}
```

#### 1b. LppCalculator

```dart
// lib/services/financial_core/lpp_calculator.dart

class LppCalculator {
  LppCalculator._();

  /// Projette l'avoir LPP a la retraite avec bonifications par age.
  /// Source : LPP art. 15-16 (bonifications), art. 14 (taux conversion)
  static LppProjection projectToRetirement({
    required double currentBalance,
    required int currentAge,
    required int retirementAge,
    required double grossAnnualSalary,
    required double caisseReturn,
    required double conversionRate,
    double monthlyBuyback = 0,
    double buybackCap = 0,
    bool isIndependent = false,  // independant = pas de bonifications sauf LPP facultative
  }) { ... }

  /// Calcule le revenu mensuel selon la strategie rente/capital.
  /// Source : LPP art. 37 (capital), LIFD art. 38 (imposition)
  static double blendedMonthly({
    required double annualRente,
    required double conversionRate,
    required double capitalPct,
    required String canton,
    bool isMarried = false,
  }) { ... }

  /// Projection mensuelle pour le forecaster (rendement + bonifications).
  /// Retourne le solde apres un mois de bonification.
  static double projectOneMonth({
    required double currentBalance,
    required int age,
    required double grossAnnualSalary,
    required double monthlyReturn,
    bool isIndependent = false,
  }) {
    // Bonification mensuelle = salaireCoord * taux(age) / 12
    // + rendement mensuel sur le solde
  }
}
```

#### 1c. TaxCalculator

```dart
// lib/services/financial_core/tax_calculator.dart

class TaxCalculator {
  TaxCalculator._();

  /// Impot retrait capital progressif (LIFD art. 38).
  /// Utilise par : LPP capital, 3a retrait.
  static double capitalWithdrawalTax({
    required double capitalBrut,
    required String canton,
    bool isMarried = false,
  }) { ... }

  /// Estimation impot revenu a la retraite.
  /// IMPORTANT : exclure les retraits SWR de capital (deja taxes au retrait).
  static double estimateRetirementIncomeTax({
    required double revenuAnnuelImposable,  // SANS les retraits capital
    required String canton,
    required String etatCivil,
  }) { ... }
}
```

#### 1d. ConfidenceScorer

```dart
// lib/services/financial_core/confidence_scorer.dart

class ConfidenceScorer {
  ConfidenceScorer._();

  static ProjectionConfidence score(CoachProfile profile) {
    double score = 0;
    final prompts = <EnrichmentPrompt>[];
    final assumptions = <String>[];

    // Donnees de base (35% max)
    if (profile.salaireBrutMensuel > 0) score += 15;
    if (profile.birthYear > 0) score += 10;
    if (profile.canton.isNotEmpty) score += 10;

    // Prevoyance (40% max)
    if (profile.prevoyance.avoirLppTotal != null && profile.prevoyance.avoirLppTotal! > 0) {
      score += 20;
    } else {
      assumptions.add('Avoir LPP estime a partir du salaire et de l\'age');
      prompts.add(EnrichmentPrompt(
        label: 'Ajoute ton solde LPP (certificat de prevoyance)',
        impact: 20,
        category: 'lpp',
      ));
    }
    if (profile.prevoyance.anneesContribuees != null) {
      score += 10;
    } else {
      assumptions.add('Annees AVS estimees a partir de l\'age');
      prompts.add(EnrichmentPrompt(
        label: 'Commande ton extrait AVS (gratuit sur caissedevs.ch)',
        impact: 10,
        category: 'avs',
      ));
    }
    if (profile.prevoyance.totalEpargne3a > 0) score += 10;

    // Patrimoine (15% max)
    if (profile.patrimoine.investissements > 0) score += 8;
    if (profile.patrimoine.epargneLiquide > 0) score += 7;

    // Archetype penalty (donnees manquantes specifiques)
    if (profile.archetype == FinancialArchetype.expatUs && !profile.hasForeignPension) {
      score -= 5;
      prompts.add(EnrichmentPrompt(
        label: 'Ajoute tes droits Social Security US',
        impact: 5,
        category: 'foreign_pension',
      ));
    }

    final level = score >= 70 ? 'high' : score >= 40 ? 'medium' : 'low';

    return ProjectionConfidence(
      score: score.clamp(0, 100),
      level: level,
      prompts: prompts..sort((a, b) => b.impact.compareTo(a.impact)),
      assumptions: assumptions,
    );
  }
}
```

### Phase 2 — Migrer RetirementProjectionService

Remplacer les methodes internes par des appels au core :

```dart
// AVANT (dans retirement_projection_service.dart) :
final avsUser = _computeAvs(currentAge: ..., retirementAge: ..., lacunes: ...);

// APRES :
final avsUser = AvsCalculator.computeMonthlyRente(
  currentAge: profile.age,
  retirementAge: ageUser,
  lacunes: profile.prevoyance.lacunesAVS ?? 0,
  anneesContribuees: profile.prevoyance.anneesContribuees,
);
```

Les methodes privees `_computeAvs`, `_projectLppToRetirement`, `_lppBlendedMonthly`,
`_estimateRetirementTax` deviennent des **redirections** vers le core, puis sont supprimees.

### Phase 3 — Migrer ForecasterService

C'est la migration la plus importante. Le ForecasterService garde :
- Sa boucle mensuelle (monthly projection points)
- Ses 3 scenarios
- Ses sliders "Et si..."

Mais remplace ses calculs internes par le core :

```dart
// AVANT (forecaster_service.dart ligne 549-550) :
final lppReturn = lppBalance * lppMonthlyRate;
lppBalance += lppReturn;
// PAS de bonifications !

// APRES :
lppBalance = LppCalculator.projectOneMonth(
  currentBalance: lppBalance,
  age: currentAge,
  grossAnnualSalary: profile.revenuBrutAnnuel,
  monthlyReturn: assumptions.lppReturn / 12,
  isIndependent: profile.employmentStatus == 'independant',
);
```

Et pour le revenu de retraite :
```dart
// AVANT (forecaster_service.dart ligne 645) :
final renteLppJulien = lppBalance * (lppTauxConversionMin / 100);
// PAS de tax !

// APRES :
final renteAvsCouple = AvsCalculator.computeCouple(
  user: AvsInput(age: profile.age, lacunes: profile.prevoyance.lacunesAVS ?? 0),
  conjoint: profile.conjoint != null ? AvsInput(...) : null,
  isCouple: profile.isCouple,
);
final lppMonthly = LppCalculator.blendedMonthly(...);
final threeANet = threeACapital - TaxCalculator.capitalWithdrawalTax(
  capitalBrut: threeACapital, canton: profile.canton,
);
```

### Phase 4 — Confidence Score UI

Ajouter sur les deux ecrans (retraite + dashboard) :

```dart
// Widget reutilisable
class ProjectionConfidenceBanner extends StatelessWidget {
  final ProjectionConfidence confidence;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: confidence.level == 'high'
            ? MintColors.success.withOpacity(0.1)
            : confidence.level == 'medium'
                ? MintColors.warning.withOpacity(0.1)
                : MintColors.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Barre de progression
          LinearProgressIndicator(value: confidence.score / 100),
          Text('Confiance : ${confidence.score.round()}%'),
          // Assumptions
          for (final a in confidence.assumptions)
            Text(a, style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic)),
          // Enrichment prompts
          for (final p in confidence.prompts.take(2))
            TextButton(
              onPressed: () => _navigateToEnrichment(p.category),
              child: Text('+${p.impact}% → ${p.label}'),
            ),
        ],
      ),
    );
  }
}
```

---

## Ordre d'execution

| Etape | Scope | Fichiers | Tests | Effort |
|-------|-------|----------|-------|--------|
| **0a** | Data plumbing : mapper spouse AVS + residence_permit | coach_profile.dart | Maj tests existants | 1h |
| **0b** | Fix _estimateLppAvoir (arrivalAge) | coach_profile.dart | 3-4 tests | 30min |
| **1a** | Extraire AvsCalculator | +avs_calculator.dart, +test | 8 tests | 1h |
| **1b** | Extraire LppCalculator | +lpp_calculator.dart, +test | 10 tests | 1.5h |
| **1c** | Extraire TaxCalculator | +tax_calculator.dart, +test | 6 tests | 45min |
| **1d** | Extraire ConfidenceScorer | +confidence_scorer.dart, +test | 5 tests | 45min |
| **2** | Migrer RetirementProjectionService → core | retirement_projection_service.dart | Maj tests existants | 2h |
| **3** | Migrer ForecasterService → core | forecaster_service.dart | Maj tests existants | 2h |
| **4** | Confidence Score UI | +widget, 2 ecrans | 3 tests UI | 1.5h |
| **5** | Cleanup : supprimer code duplique | both services | Verify all green | 30min |

**Total estime : ~12h de travail agent (~4 sprints de 3h)**

---

## Regles de migration

1. **Un calculator a la fois** — jamais deux en parallele
2. **Tests d'abord** — ecrire les tests du core AVANT de migrer
3. **Golden tests** — capturer les outputs actuels de RetirementProjectionService comme reference
4. **Regression check** — apres chaque migration, les outputs doivent matcher les golden tests
5. **ForecasterService DOIT matcher RetirementProjectionService** — c'est le but principal
6. **Pas de nouvelles features pendant la migration** — pure refactoring
7. **Commit apres chaque phase** — rollback facile

---

## Metriques de succes

1. **Zero divergence** : dashboard et ecran retraite affichent le meme revenu (±1%)
2. **Zero duplication** : chaque formule (AVS, LPP, tax) n'existe qu'une fois
3. **Confidence score** visible sur les deux ecrans
4. **Tests core** : minimum 30 tests unitaires dans financial_core/
5. **Flutter analyze** : 0 erreurs
6. **Regression** : tous les tests existants passent

---

## Liens

- ADR-20260223-archetype-driven-retirement.md — Archetypes financiers (Phase 5 future)
- CLAUDE.md — Constantes, conventions, anti-patterns
- LPP art. 15-16 — Bonifications vieillesse
- LIFD art. 38 — Imposition prestations en capital
- LAVS art. 21-29, 34, 35, 40 — Rente AVS
- OPP3 art. 7 — Plafonds 3a
