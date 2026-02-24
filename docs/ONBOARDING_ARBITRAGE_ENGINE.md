# ONBOARDING_ARBITRAGE_ENGINE.md — MINT Evolution Spec

> Companion to `CLAUDE.md`. Guides the next evolution of MINT:
> simplified onboarding, arbitrage transparency engine, adaptive UX,
> financial resilience scoring, and longitudinal tracking.
>
> **This document does NOT replace CLAUDE.md.** It extends it.
> All rules, constants, compliance, and anti-patterns from CLAUDE.md remain in force.

---

## TABLE OF CONTENTS

1. [Design Philosophy](#i-design-philosophy)
2. [Onboarding Redesign](#ii-onboarding-redesign)
3. [Arbitrage Transparency Engine](#iii-arbitrage-transparency-engine)
4. [Adaptive UX Engine](#iv-adaptive-ux-engine)
5. [Financial Resilience Index (FRI)](#v-financial-resilience-index-fri)
6. [Longitudinal Snapshot System](#vi-longitudinal-snapshot-system)
7. [Reengagement Engine](#vii-reengagement-engine)
8. [Implementation Roadmap](#viii-implementation-roadmap)
9. [Compliance Addendum](#ix-compliance-addendum)
10. [Anti-Patterns Addendum](#x-anti-patterns-addendum)

---

## I. DESIGN PHILOSOPHY

### Core Principle

```
Complex inside. Radically simple outside.
```

MINT's sophistication lives in the backend. The user sees:
- **1 number** that matters right now
- **1 action** they can take
- **1 explanation** if they want it

### The Three Laws of MINT UX

1. **Never teach the system. Always resolve an anxiety.**
   - Wrong: "Here's how the 3 pillars work."
   - Right: "If you stop working for 6 months, you have X months of runway."

2. **Never show more than one new concept at a time.**
   - Complexity unlocks progressively, driven by user curiosity, not by app structure.

3. **Every number must be personal.**
   - No generic stats. Everything computed from the user's actual inputs via `financial_core/`.

### Information Architecture

```
Layer 1 — Signal       → 1 number, 1 priority (always visible)
Layer 2 — Action       → 1 dominant action with simulated impact
Layer 3 — Exploration  → Modules, deep simulators, comparisons (on demand)
Layer 4 — Expert       → Full parameters, hypotheses, sensitivity (hidden by default)
```

---

## II. ONBOARDING REDESIGN

### Problem

Current onboarding collects too much before showing value.
Users who don't understand Swiss finance drop off before seeing why MINT matters.

### Solution: Value-First Onboarding

Show a meaningful result within 30 seconds, then earn the right to ask more.

### Flow

#### Step 1 — 3 Questions (30 seconds)

```
Q1: Salaire brut annuel        → Slider with presets (60k, 80k, 100k, 120k, 150k+)
Q2: Âge                        → Number picker
Q3: Canton                     → Dropdown (26 cantons)
```

That's it. No family situation, no savings, no property status.

With these 3 inputs + sensible defaults, `financial_core/` can already compute:
- Projected AVS rente (via `AvsCalculator`)
- Estimated LPP accumulation (via `LppCalculator`, using age-band bonifications)
- Estimated marginal tax rate (via `TaxCalculator`)
- 3a tax savings (marginal rate × 7'258)
- Approximate replacement ratio

#### Step 2 — The Chiffre Choc (immediate value)

One screen. One number. Maximum emotional impact.

```
┌──────────────────────────────────────────┐
│                                          │
│  À la retraite, ton revenu mensuel       │
│  estimé serait de                        │
│                                          │
│         CHF 3'420 / mois                 │
│                                          │
│  Aujourd'hui, tu dépenses probablement   │
│  autour de CHF 5'800 / mois.            │
│                                          │
│  ─────────────────────────────           │
│  Estimation basée sur 3 informations.    │
│  Plus tu précises, plus c'est fiable.    │
│                                          │
│         [ Qu'est-ce que je peux faire? ] │
│                                          │
│         [ Affiner mon profil ↓ ]         │
│                                          │
└──────────────────────────────────────────┘
```

**Chiffre choc selection logic** (in `ChiffreChocSelector`):

| Condition | Chiffre choc | Angle |
|-----------|-------------|-------|
| Replacement ratio < 55% | Monthly retirement income vs expenses | Gap anxiety |
| 3a not used AND tax saving > 1'500 CHF | Annual tax saving left on table | Lost money |
| Liquid reserves < 2 months expenses | Months of runway without income | Security |
| Mortgage stress > 38% of income | Monthly overcommitment amount | Stress |
| LPP buyback potential > 20'000 CHF | Cumulative tax saving over 5 years | Opportunity |

Priority order: Security > Gap > Lost money > Opportunity > Stress.

Only **one** chiffre choc shown. Never two.

#### Step 3 — One Action

Based on the chiffre choc, suggest ONE action:

```
"Tu pourrais économiser CHF 1'820 d'impôt cette année en ouvrant un 3e pilier."

        [ Simuler → ]
```

Not a recommendation. A simulation invitation.

#### Step 4 — Progressive Enrichment

Each additional question immediately recalculates the chiffre choc:

```
Round 2 (optional):
  - Situation familiale (célibataire / couple / enfants)
  - Épargne actuelle (fourchette)
  - Propriétaire ou locataire

Round 3 (optional):
  - 3a existant (oui/non, montant)
  - Type de caisse LPP (base / complémentaire)
  - Dettes en cours
```

**Key UX rule**: After each answer, the chiffre choc updates in real-time.
The user sees the value of each piece of information they provide.

### Backend Implementation

#### New Service: `MinimalProfileService`

```
lib/services/minimal_profile_service.dart
```

Purpose: Generate meaningful projections from minimal inputs (3 fields) using defaults.

```dart
class MinimalProfileService {
  /// Computes key financial indicators from just age, salary, canton.
  /// Uses sensible Swiss defaults for all missing fields.
  MinimalProfileResult compute({
    required int age,
    required double grossSalary,
    required String canton,
    // Optional enrichment fields (null = use defaults)
    String? householdType,      // default: "single"
    double? currentSavings,     // default: estimated from age + salary
    bool? isPropertyOwner,      // default: false
    double? existing3a,         // default: 0
    double? existingLpp,        // default: estimated from age + salary
  });
}
```

**Default estimation logic**:
- `currentSavings`: `max(0, (age - 25) * grossSalary * 0.05)` (conservative 5% savings rate)
- `existingLpp`: `LppCalculator.projectToRetirement()` with bonifications from age 25
- `monthlyExpenses`: `netSalary * 0.85` (Swiss average consumption ratio)
- `householdType`: `"single"` (safe default, overestimates needs)

All defaults clearly flagged in output as `isEstimated: true`.

#### New Service: `ChiffreChocSelector`

```
lib/services/chiffre_choc_selector.dart
```

```dart
class ChiffreChocSelector {
  /// Selects the single most impactful number for this profile.
  /// Returns exactly one ChiffreChoc with explanation and action.
  ChiffreChoc select(MinimalProfileResult profile);
}

class ChiffreChoc {
  final String category;        // "retirement_gap", "tax_saving", "liquidity", etc.
  final double primaryNumber;
  final String displayText;     // User-facing text (French, informal)
  final String explanationText; // Layer 2 explanation
  final String actionText;      // Suggested simulation
  final String disclaimer;      // ALWAYS present
  final List<String> sources;   // Legal references
  final double confidenceScore; // From ConfidenceScorer
}
```

**MUST use `financial_core/` calculators. NEVER duplicate logic.**

#### Backend Mirror

```
services/backend/app/services/onboarding/
    minimal_profile_service.py
    chiffre_choc_selector.py
```

Backend = source of truth. Flutter service must produce identical results.

---

## III. ARBITRAGE TRANSPARENCY ENGINE

### What This Is

A comparison engine that shows two (or more) financial trajectories side by side.
User sees the curves, the crossover point, the hypotheses.
User decides. MINT never decides.

### What This Is NOT

- Not a recommendation engine
- Not an optimizer
- Not a ranking system
- Not a robo-advisor

### Core Principle

```
MINT shows deltas, not decisions.
MINT shows trajectories, not verdicts.
MINT shows hypotheses, not truths.
```

### Architecture

```
lib/services/financial_core/
    avs_calculator.dart            # exists
    lpp_calculator.dart            # exists
    tax_calculator.dart            # exists
    confidence_scorer.dart         # exists
    arbitrage_engine.dart          # NEW — comparison orchestrator
    arbitrage_models.dart          # NEW — shared result types
```

The `ArbitrageEngine` is a **consumer** of `financial_core/` calculators.
It NEVER reimplements tax, AVS, or LPP logic.

### Data Model

```dart
/// A single option in a comparison
class TrajectoireOption {
  final String id;                    // e.g. "lpp_buyback", "market_invest"
  final String label;                 // User-facing label (French)
  final List<YearlySnapshot> trajectory;  // Year-by-year projection
  final double terminalValue;         // End-of-horizon net patrimony
  final double cumulativeTaxImpact;   // Total tax paid/saved over horizon
}

class YearlySnapshot {
  final int year;
  final double netPatrimony;          // Total net worth at year-end
  final double annualCashflow;        // Net in/out that year
  final double cumulativeTaxDelta;    // vs baseline
}

/// The full result of an arbitrage comparison
class ArbitrageResult {
  final List<TrajectoireOption> options;
  final int? breakevenYear;           // Year when curves cross (null if never)
  final String chiffreChoc;           // The single most striking delta
  final String displaySummary;        // One-sentence summary
  final List<String> hypotheses;      // ALWAYS explicit — user can modify
  final String disclaimer;            // ALWAYS present
  final List<String> sources;         // Legal references
  final double confidenceScore;
  final Map<String, double> sensitivity;  // Key: parameter, Value: impact of ±1%
}
```

### The 5 Arbitrage Modules

#### Module A: Location vs Propriété

**Inputs**: capital disponible, loyer actuel, prix du bien, canton, horizon

**What it compares**:
- Option 1: Continue renting + invest capital at market return
- Option 2: Buy property (mortgage at theoretical 5% + real rate, amortization, maintenance 1%, valeur locative, tax deduction interests)

**Critical variables most people miss** (MINT's educational edge):
- Opportunity cost of equity locked in property (20% fonds propres earning 0%)
- Valeur locative adding to taxable income
- Real maintenance costs (not the 1% rule — actual Swiss averages by property age)
- Concentration risk (80%+ of net worth in one illiquid asset)

**Crossover display**: "Avec un rendement marché de X% et une appréciation immobilière de Y%, la location devient plus avantageuse après Z ans."

**Legal sources**: CO art. 253ss, LIFD art. 21/32, FINMA Tragbarkeit

```dart
ArbitrageResult compareLocationVsPropriete({
  required double capitalDisponible,
  required double loyerMensuelActuel,
  required double prixBien,
  required String canton,
  required int horizonAnnees,
  // Modifiable hypotheses (with defaults)
  double rendementMarche = 0.04,
  double appreciationImmo = 0.015,
  double tauxHypotheque = 0.02,      // real rate
  double tauxEntretien = 0.01,
});
```

#### Module B: Rachat LPP vs Investissement Marché

**Inputs**: montant disponible, taux marginal (auto-computed), taux de conversion caisse, années avant retraite

**What it compares**:
- Option 1: LPP buyback → immediate tax deduction, capital locked, converted at caisse rate, taxed at withdrawal
- Option 2: Market investment → no deduction, full liquidity, market return, taxed on income/gains

**The breakeven calculation most people need**:
```
Rendement implicite du rachat ≈ tauxMarginal / horizon - tauxImpotRetrait / horizon
```
If this exceeds expected market return net of tax → buyback wins.
If not → market wins.

But this is simplified. The real comparison needs year-by-year trajectories with:
- Tax savings reinvested (rachat scenario)
- Opportunity cost of illiquidity
- Sensitivity to conversion rate changes

**Legal sources**: LPP art. 79b, LIFD art. 33/38, OPP2

```dart
ArbitrageResult compareRachatVsMarche({
  required double montant,
  required int annéesAvantRetraite,
  required double tauxMarginal,           // from TaxCalculator
  required double tauxConversionCaisse,   // user input or default 6.8%
  double rendementMarche = 0.04,
  double rendementLpp = 0.02,             // LPP minimum guarantee
});
```

#### Module C: Rente vs Capital LPP

**Inputs**: capital LPP, rente annuelle proposée, canton, âge retraite

**What it compares**:
- Option 1: Full rente → taxed as income every year (LIFD art. 22), longevity-protected, lost at death (minus reversion)
- Option 2: Full capital → taxed once at withdrawal (LIFD art. 38), SWR strategy, inheritable, market risk
- Option 3: Mixed → obligatoire as rente (6.8% conversion), surobligatoire as capital

**The breakeven everyone needs**:
```
Breakeven age = Capital / Rente annuelle nette + Âge retraite
```
(Simplified. Real calculation includes tax differential, investment return on capital, inflation.)

**Critical insight MINT must surface**:
The 6.8% conversion rate on obligatoire LPP is an **implicit guaranteed return of ~4-5%**.
No risk-free market instrument offers this. Taking the rente on obligatoire is almost always rational.
On surobligatoire (often 4.5-5.5% conversion), the case for capital is much stronger.

→ The mixed strategy is often superior but rarely modeled. MINT models it.

**Legal sources**: LPP art. 14/37, LIFD art. 22/38, LAVS art. 35 (couple cap)

```dart
ArbitrageResult compareRenteVsCapital({
  required double capitalLppTotal,
  required double capitalObligatoire,
  required double capitalSurobligatoire,
  required double renteAnnuelleProposee,
  required double tauxConversionObligatoire,   // usually 6.8%
  required double tauxConversionSurobligatoire, // user's caisse
  required String canton,
  required int ageRetraite,
  double tauxRetrait = 0.04,        // SWR on capital portion
  double rendementCapital = 0.03,   // conservative post-retirement
});
```

#### Module D: Allocation Annuelle ("J'ai X CHF, où les mettre?")

**Inputs**: montant disponible, profil utilisateur complet

**What it compares** (up to 4 options side by side):
- 3a (if not maxed): tax saving this year + projected growth
- Rachat LPP (if eligible): tax saving + LPP growth at caisse rate
- Amortissement indirect (if property owner): tax optimization on mortgage
- Investissement libre: market return, no tax deduction, full liquidity

**Display**: 4 columns, same horizon, same starting amount. Trajectory chart.

**Legal sources**: OPP3 art. 7, LPP art. 79b, LIFD art. 33, CO art. 793ss

```dart
ArbitrageResult compareAllocationAnnuelle({
  required double montantDisponible,
  required double tauxMarginal,
  required bool a3aMaxed,
  required double potentielRachatLpp,
  required bool isPropertyOwner,
  required double? tauxHypothecaire,
  required int annéesAvantRetraite,
});
```

#### Module E: Calendrier de Retraits (Withdrawal Scheduling)

**Inputs**: all retirement assets (3a accounts, LPP, libre passage)

**What it compares**:
- Option 1: Withdraw everything same year
- Option 2: Optimal staggering over 3-5 years (3a at 60, LPP at 63, spouse 3a at 64...)

**The wow number**: "En étalant tes retraits sur 5 ans, tu économises CHF X d'impôt."

This is often the single biggest fiscal optimization available, and the least known.

Uses `TaxCalculator.capitalWithdrawalTax()` with progressive brackets from CLAUDE.md.

**Legal sources**: LIFD art. 38, OPP3 art. 3 (3a withdrawal from 59/60)

```dart
ArbitrageResult compareCalendrierRetraits({
  required List<RetirementAsset> assets,  // {type, amount, earliestWithdrawalAge}
  required int ageRetraite,
  required String canton,
  required bool isMarried,
});
```

### Arbitrage Engine — Compliance Rules

In addition to all CLAUDE.md compliance rules, the arbitrage engine MUST:

1. **Never rank options.** Display side by side, never "Option A is better."
2. **Always show hypotheses.** Every assumption must be visible and modifiable.
3. **Always show the crossover.** If curves cross, show when and under what conditions.
4. **Always show sensitivity.** "If market return drops by 1%, the result reverses."
5. **Always include disclaimer + sources.**
6. **Never use "optimal", "meilleur", "recommandé".**
7. **Use conditional language**: "Dans ce scénario simulé, avec ces hypothèses..."

### Wording Templates (Compliant)

```
✅ ALLOWED:
"Dans ce scénario, le rachat LPP produit un patrimoine net supérieur
 de CHF 18'400 sur 15 ans."

"Si le rendement marché dépasse 5.2%, le résultat s'inverse."

"L'écart fiscal cumulé entre les deux options est de CHF 12'300
 sur la période simulée."

"En étalant tes retraits, l'impôt total simulé diminue de CHF 23'000."

❌ BANNED:
"Le rachat LPP est plus avantageux."
"Tu devrais choisir le capital."
"La meilleure option est..."
"Nous te recommandons..."
"Il est optimal de..."
```

### Backend Mirror

```
services/backend/app/services/arbitrage/
    arbitrage_engine.py
    arbitrage_models.py
    location_vs_propriete.py
    rachat_vs_marche.py
    rente_vs_capital.py
    allocation_annuelle.py
    calendrier_retraits.py
tests/
    test_arbitrage_engine.py      # Min 15 tests per module
```

---

## IV. ADAPTIVE UX ENGINE

### What Drives Adaptation

MINT adapts based on 3 objective signals. NOT behavioral profiling.

#### Signal 1: Archetype (already exists)

The 8 archetypes from CLAUDE.md drive priority ordering:

| Archetype | Priority 1 | Chiffre Choc Default | Priority 2 |
|-----------|-----------|----------------------|-----------|
| `swiss_native` < 30 | 3a + liquidity | Tax saving 3a | Retirement gap |
| `swiss_native` 30-50 | Retirement + tax | Replacement ratio | Rachat LPP |
| `swiss_native` 50+ | Rente vs capital | Breakeven age | Withdrawal calendar |
| `expat_eu` | AVS gaps | Missing contribution years | Bilateral agreements |
| `expat_non_eu` | AVS gaps | Missing years (no bilateral) | 3a urgency |
| `expat_us` | FATCA + double tax | Hidden tax exposure | 3a restrictions |
| `independent_with_lpp` | LPP adequacy | Gap vs salarié equivalent | Rachat potential |
| `independent_no_lpp` | 3a extended + gap | Retirement shortfall | Voluntary LPP |
| `cross_border` | Source tax + LPP | Tax differential | Convention bilatérale |
| `returning_swiss` | Gaps + libre passage | Buyback opportunity | AVS catch-up |

This matrix drives: onboarding chiffre choc, default module ordering, notification priority.

#### Signal 2: Profile Completeness (ConfidenceScorer)

| Confidence | UX Behavior |
|-----------|-------------|
| < 40% | Show wide ranges. Push enrichment. "Cette estimation est approximative." |
| 40-70% | Show ranges with central estimate. Suggest specific missing fields. |
| > 70% | Show point estimates with sensitivity. Enable arbitrage modules. |
| > 90% | Enable advanced comparisons and longitudinal tracking. |

**Rule**: Arbitrage modules require confidence > 60%. Below that, results are misleading.

#### Signal 3: Swiss Calendar (temporal relevance)

| Period | Push | Rationale |
|--------|------|-----------|
| Oct-Dec | 3a contribution | Deadline Dec 31 |
| Jan-Mar | Tax declaration prep | Cantonal deadlines |
| Any | Job change detected | LPP libre passage decision window |
| Any | Birth event | Protection gap review |
| 5 years before retirement | Rente vs capital | Decision horizon |
| 3 years before retirement | Withdrawal calendar | Staggering planning |

The Proactive Coaching Engine (S11) already handles some of this.
Extend it with arbitrage-specific triggers.

### Implementation

#### New: `AdaptivePriorityService`

```
lib/services/adaptive_priority_service.dart
```

```dart
class AdaptivePriorityService {
  /// Returns ordered list of modules/actions for this user right now.
  /// Combines archetype + confidence + calendar signals.
  List<PrioritizedAction> getPriorities({
    required String archetype,
    required double confidenceScore,
    required DateTime now,
    required MinimalProfileResult profile,
  });
}

class PrioritizedAction {
  final String moduleId;
  final String displayText;
  final double estimatedImpact;     // In CHF or percentage
  final String impactExplanation;
  final bool requiresEnrichment;    // If confidence too low
}
```

**NOT a ranking of "best actions".** An ordering of "most relevant topics right now"
based on objective signals (archetype, completeness, calendar).

---

## V. FINANCIAL RESILIENCE INDEX (FRI)

### What It Is

A composite score (0-100) measuring the user's financial solidity across 4 dimensions.
Not a judgment. A progression tracker.

### What It Is NOT

- Not a credit score
- Not a grade (never display "bon" / "mauvais")
- Not a comparison with other users
- Not a recommendation

### Structure

```
FRI = L + F + R + S

L = Liquidity        (0-25)
F = Fiscal Efficiency (0-25)
R = Retirement        (0-25)
S = Structural Risk   (0-25)
```

### Component Calculations

#### L — Liquidity (0-25)

```dart
double monthsCover = liquidAssets / monthlyFixedCosts;

// Non-linear: first months matter most
double L = 25 * min(1.0, sqrt(monthsCover / 6.0));

// Penalties
if (shortTermDebtRatio > 0.30) L -= 4;
if (incomeVolatility == "high") L -= 3;  // independants

L = clamp(L, 0, 25);
```

Why `sqrt`? Diminishing returns. Going from 0→1 month is critical.
Going from 5→6 months is marginal. Square root captures this.

#### F — Fiscal Efficiency (0-25)

```dart
double utilisation3a = actual3a / max3a;  // 0-1
double utilisationRachat = 0;
if (potentielRachatLpp > 0 && tauxMarginal > 0.25) {
  utilisationRachat = rachatEffectue / potentielRachatLpp;
}
double utilisationAmortIndirect = isPropertyOwner ? (amortIndirect > 0 ? 1.0 : 0.0) : 1.0;

// Weighted average (3a most accessible, highest weight)
double F = 25 * (0.6 * utilisation3a + 0.25 * utilisationRachat + 0.15 * utilisationAmortIndirect);

F = clamp(F, 0, 25);
```

**Important**: The rachat LPP component only penalizes if `tauxMarginal > 25%`.
Below that, not buying back is rational — MINT doesn't penalize rational non-action.

#### R — Retirement (0-25)

```dart
double replacementRatio = projectedRetirementIncome / currentNetIncome;
double targetRatio = 0.70;  // Swiss standard benchmark

// Non-linear: being at 60% is much better than 30%, but 80% vs 70% is marginal
double R = 25 * min(1.0, pow(replacementRatio / targetRatio, 1.5));

R = clamp(R, 0, 25);
```

Uses `AvsCalculator` + `LppCalculator` + any 3a projections. Never duplicates.

#### S — Structural Risk (0-25)

```dart
double S = 25;

// Penalty: disability gap
if (disabilityGapRatio > 0.20) S -= 6;

// Penalty: death protection gap (if dependents)
if (hasDependents && deathProtectionGapRatio > 0.30) S -= 6;

// Penalty: mortgage stress
if (mortgageStressRatio > 0.36) S -= 5;  // Above 1/3 FINMA guideline

// Penalty: concentration (>70% net worth in single asset)
if (concentrationRatio > 0.70) S -= 4;

// Penalty: employer dependency (LPP + salary from same source)
if (employerDependencyRatio > 0.80) S -= 4;

S = clamp(S, 0, 25);
```

### FRI Display Rules

```
✅ ALLOWED:
"Solidité financière : 47 / 100"
"Progression : +4 ce trimestre"
"Ton point le plus fragile : réserve de liquidité"
"Action pour progresser : constituer 2 mois de réserve"

❌ BANNED:
"Score faible"
"Mauvais résultat"
"Tu es en danger"
"Ton score est inférieur à la moyenne" (no social comparison)
```

### FRI — Backend Model

```dart
@dataclass
class FriBreakdown {
  final double liquidite;
  final double fiscalite;
  final double retraite;
  final double risque;
  final double total;
  final String modelVersion;      // e.g. "1.0.0"
  final DateTime computedAt;
  final double confidenceScore;   // From ConfidenceScorer
}
```

### FRI — API

```
GET  /api/v1/fri/current          → FriBreakdown
GET  /api/v1/fri/history          → List<FriBreakdown> (longitudinal)
POST /api/v1/fri/simulate-action  → { deltaFri, newBreakdown }
```

### FRI — Required Confidence

FRI should only be displayed when `confidenceScore >= 50%`.
Below that, show: "Complète ton profil pour débloquer ton score de solidité."

---

## VI. LONGITUDINAL SNAPSHOT SYSTEM

### Purpose

Track the user's financial state over time. Enable "you vs yourself 6 months ago."

### Data Model

```sql
-- New table
CREATE TABLE financial_snapshots (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL,
    created_at TIMESTAMP NOT NULL,
    trigger TEXT NOT NULL,                -- "manual", "quarterly", "life_event", "action_simulated"
    model_version TEXT NOT NULL,

    -- Core inputs (from profile at time of snapshot)
    age INT,
    gross_income FLOAT,
    canton TEXT,
    archetype TEXT,
    household_type TEXT,

    -- Key outputs (computed by financial_core)
    replacement_ratio FLOAT,
    months_liquidity FLOAT,
    tax_saving_potential FLOAT,
    fri_total FLOAT,
    fri_liquidite FLOAT,
    fri_fiscalite FLOAT,
    fri_retraite FLOAT,
    fri_risque FLOAT,
    confidence_score FLOAT,

    -- Metadata
    enrichment_fields_count INT          -- How many optional fields were filled
);
```

### Snapshot Triggers

| Trigger | When |
|---------|------|
| `quarterly` | Automatic every 3 months |
| `life_event` | When user declares a life event |
| `profile_update` | When user significantly changes inputs |
| `action_simulated` | When user completes an arbitrage simulation (stores the "before") |

### What This Enables

- "Il y a 6 mois, ton taux de remplacement était de 52%. Aujourd'hui: 61%."
- FRI evolution chart over 12+ months
- Proof of progression (retention driver)
- Data for future calibration and model improvement

### Privacy

- Snapshots encrypted at rest (LPD compliance)
- User can delete all snapshots at any time
- Snapshots never sent to LLM layer
- Retention: maximum 5 years, then auto-purged

---

## VII. REENGAGEMENT ENGINE

### Principle

Reengagement must be personalized, quantified, and never generic.

### What NEVER to Send

```
❌ "Tu n'as pas utilisé MINT depuis 14 jours."
❌ "Reviens découvrir nos nouvelles fonctionnalités!"
❌ "Tu nous manques!"
```

### What to Send

```
✅ "Il te reste 47 jours pour verser ton 3a et économiser ~CHF 1'820 d'impôt." [Oct-Dec]
✅ "Ton taux de remplacement a changé suite à la mise à jour des paramètres AVS 2026."
✅ "Tu as simulé un rachat LPP en septembre. Le délai de 3 ans expire en septembre 2029."
```

Every notification must contain:
- A **personal number** (CHF amount, percentage, date)
- A **time constraint** (deadline, window, expiry)
- A **link to the relevant simulation**

### Reengagement Calendar

| Month | Trigger | Content |
|-------|---------|---------|
| January | New year | "Nouveaux plafonds 3a: CHF X. Ton économie potentielle: CHF Y." |
| February | Tax prep | "Prépare ta déclaration: voici tes chiffres clés." |
| March | Tax deadline (varies) | "Deadline canton de [X]: [date]." |
| October | 3a countdown | "Il reste 92 jours pour ton versement 3a." |
| November | 3a urgency | "Il reste 45 jours. Économie estimée: CHF X." |
| December | 3a final | "Dernier mois. CHF X d'économie en jeu." |
| Quarterly | FRI update | "Ton score de solidité: [X] (+[Y] ce trimestre)." |

---

## VIII. IMPLEMENTATION ROADMAP

### Phased Rollout (no big bang)

| Phase | Sprint | Scope | Dependencies |
|-------|--------|-------|-------------|
| **Phase 1** | S31 | `MinimalProfileService` + `ChiffreChocSelector` + onboarding flow | `financial_core/` (exists) |
| **Phase 2** | S32 | `ArbitrageEngine` — Rente vs Capital (enriched with mixed scenario) | `TaxCalculator`, `LppCalculator` |
| **Phase 3** | S33 | `ArbitrageEngine` — Allocation annuelle + Calendrier retraits | `TaxCalculator` |
| **Phase 4** | S34 | Compliance Guard (blocker LLM) | Coach layer S35+ |
| **Phase 5** | S35 | `AdaptivePriorityService` + Coach Narrative scaffolding | Onboarding + Archetypes + S34 |
| **Phase 6** | S36 | Notifications + milestones | S35 |
| **Phase 7** | S37 | Scenario narration + annual refresh | S36 |
| **Phase 8** | S38 | FRI shadow mode (computed, not displayed) + snapshot feed | Phases 1-7 |
| **Phase 9** | S39 | FRI beta display + longitudinal charts | Phase 8 validated |

### Test Requirements per Phase

- Phase 1: Min 20 backend tests + 10 Flutter smoke tests
- Phases 2-4: Min 15 tests per arbitrage module (edge cases + compliance wording checks)
- Phases 8-9: FRI calibration tests against known profiles
- All phases: `flutter analyze` = 0 errors, all existing tests still pass

---

## IX. COMPLIANCE ADDENDUM

### Arbitrage-Specific Compliance (extends CLAUDE.md rules)

1. **No ranking of options.** Side-by-side only. Never "Option A > Option B."
2. **Hypotheses always visible and modifiable.** User must be able to change rendement, inflation, horizon.
3. **Sensitivity always shown.** "Si le rendement passe de 4% à 3%, le résultat s'inverse."
4. **Conditional language mandatory.** "Dans ce scénario simulé..." not "Tu gagneras..."
5. **Mixed scenarios for rente vs capital.** ALWAYS offer the obligatoire/surobligatoire split view.
6. **Progressive brackets explicit.** When showing withdrawal tax, show the bracket breakdown.
7. **Crossover point mandatory.** If trajectories cross, show when. If they don't cross in the horizon, say so.

### FRI-Specific Compliance

1. **Never frame as judgment.** "Progression" not "score."
2. **Never compare to other users.** Only compare to user's own past.
3. **Never say "faible", "mauvais", "insuffisant".**
4. **Always show decomposition.** Never just the total without breakdown.
5. **Always show how to improve.** Every FRI display includes the top action.

### LPD (Data Protection) Addendum

1. **Financial snapshots = sensitive data.** Encryption at rest mandatory.
2. **Longitudinal tracking = profiling under nLPD art. 5 let. f.** Requires explicit consent.
3. **Consent must be granular:** snapshot storage separate from basic app usage.
4. **Right to deletion:** User can purge all snapshots instantly.
5. **Data minimization:** Snapshots store aggregated outputs, not raw bank data.

---

## X. ANTI-PATTERNS ADDENDUM

Extends the anti-patterns list in CLAUDE.md:

15. **Show all options equally weighted** — Always surface ONE dominant action via `AdaptivePriorityService`. Others accessible but secondary.
16. **Display FRI below confidence threshold** — FRI requires `confidenceScore >= 50%`. Below that, push enrichment.
17. **Rank arbitrage options** — NEVER sort by "best". Display side by side with crossover.
18. **Use generic reengagement** — Every notification must contain a personal number + time constraint.
19. **Show arbitrage without modifiable hypotheses** — User MUST be able to change assumptions and see impact.
20. **Ignore the mixed rente/capital scenario** — ALWAYS offer the obligatoire vs surobligatoire split as a third option.
21. **Compute FRI without `financial_core/`** — FRI components MUST use existing calculators. Never reimplement AVS/LPP/tax logic.
22. **Store snapshots without consent** — Longitudinal tracking requires explicit opt-in (nLPD).
23. **Display chiffre choc from defaults without flagging** — If computation uses estimated defaults (not user-provided data), always show "Estimation basée sur [N] informations. Affine ton profil pour plus de précision."

---

## HIERARCHY OF TRUTH (updated)

In case of conflict, priority order:

```
1. rules.md                              — Non-negotiable ethical rules
2. CLAUDE.md                             — Project context + constants
3. ONBOARDING_ARBITRAGE_ENGINE.md        — THIS FILE (evolution spec)
4. AGENTS.md                             — Team workflow
5. visions/                              — Product vision
6. LEGAL_RELEASE_CHECK.md                — Wording compliance
7. decisions/ (ADR)                      — Architecture decisions
8. Code                                  — Implementation follows documents
```

This file sits below CLAUDE.md. If anything here contradicts CLAUDE.md, CLAUDE.md wins.

---

*Document version: 1.0 — February 2026*
*Author: Senior Dev + Product Architecture*
*Status: Approved for implementation planning*
