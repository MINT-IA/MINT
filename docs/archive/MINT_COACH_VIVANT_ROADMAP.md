# MINT_COACH_VIVANT_ROADMAP.md — Definitive Execution Plan

> **Scope**: Plan d'execution sprint pour Coach Vivant (S31-S45 dependances, ordering, specs).
> **Companions**: BLUEPRINT_COACH_AI_LAYER.md (architecture technique), UX_REDESIGN_COACH.md (design UX).

> Integrates: Coach Layer (T1-T7) + Arbitrage Engine + Onboarding Redesign
> + Compliance Guards + Longitudinal Tracking
>
> This is the master execution document. It supersedes the standalone
> "Plan Révolutionnaire" and complements both `CLAUDE.md` and
> `ONBOARDING_ARBITRAGE_ENGINE.md`.

---

## EXECUTIVE SUMMARY

MINT evolves from financial calculator to living financial coach through 3 parallel tracks:

```
Track A — FOUNDATION       (Sprints S31-S33)
           Onboarding + Arbitrage + Snapshots
           → User gets value in 30 seconds
           → User can compare financial options
           → User's state is tracked over time

Track B — COACH LAYER       (Sprints S34-S37)
           Compliance Guard + Narrative Engine + Notifications
           → Every text becomes personal (with BYOK)
           → App works perfectly without BYOK
           → Legal safety guaranteed by automated guards

Track C — ENGAGEMENT LOOP   (Sprints S38-S40)
           FRI + Milestones + Reengagement + Annual Refresh
           → User has a progression score
           → User is celebrated for progress
           → User is reengaged with personal numbers
```

Track A runs first (it has no LLM dependency).
Track B requires Track A outputs (chiffre choc, arbitrage results, snapshots).
Track C requires both A and B.

---

## TRACK A — FOUNDATION (No LLM Required)

### S31 — Onboarding Redesign + MinimalProfileService

**Goal**: Value in 30 seconds. 3 questions → 1 chiffre choc → 1 action.

**Deliverables**:

Backend:
```
services/backend/app/services/onboarding/
    minimal_profile_service.py        # 3 inputs → full projection with defaults
    chiffre_choc_selector.py          # Selects THE number that matters
    tests/test_minimal_profile.py     # Min 20 tests
    tests/test_chiffre_choc.py        # Min 15 tests
```

Flutter:
```
apps/mobile/lib/
    services/minimal_profile_service.dart
    services/chiffre_choc_selector.dart
    screens/onboarding/
        onboarding_minimal_screen.dart     # 3 questions (salary, age, canton)
        chiffre_choc_screen.dart           # THE number + 1 CTA
        progressive_enrichment_screen.dart  # Optional additional questions
```

**Spec — MinimalProfileService**:

Inputs (required): age, grossSalary, canton.
Inputs (optional): householdType, currentSavings, isPropertyOwner, existing3a, existingLpp.

Default estimation when optional fields are null:
- monthlyExpenses: netSalary × 0.85
- currentSavings: max(0, (age - 25) × grossSalary × 0.05)
- existingLpp: LppCalculator.projectToRetirement() from age 25
- householdType: "single"

All defaults flagged as `isEstimated: true` in output.

MUST use `financial_core/` calculators. Zero duplication.

**Spec — ChiffreChocSelector**:

Priority order (highest urgency first):
1. Liquidity < 2 months → "Tu pourrais tenir X mois sans revenu."
2. Replacement ratio < 55% → "À la retraite, ton revenu estimé : CHF X/mois."
3. 3a unused AND saving > 1'500 → "Tu laisses ~CHF X d'économie fiscale par an."
4. LPP buyback > 20k AND marginal > 25% → "Un rachat LPP pourrait réduire ton impôt de CHF X."
5. Mortgage stress > 38% → "Tes charges représentent X% de ton revenu."

Returns exactly ONE chiffre choc. Never two.

**Test requirements**:
- 8 archetype × 3 age bands = 24 profile combinations minimum
- Each must produce a valid chiffre choc
- All chiffres validated against financial_core output
- Wording compliance check (no banned terms)
- Confidence score attached to every output

---

### S32 — Arbitrage Engine Phase 1 (Rente vs Capital + Allocation Annuelle)

**Goal**: Users can compare their most critical financial decisions.

**Deliverables**:

Backend:
```
services/backend/app/services/arbitrage/
    arbitrage_engine.py
    arbitrage_models.py
    rente_vs_capital.py          # With mixed oblig/suroblig scenario
    allocation_annuelle.py       # 3a vs rachat vs amort indirect vs marché
    tests/test_rente_vs_capital.py    # Min 15 tests
    tests/test_allocation_annuelle.py # Min 15 tests
```

Flutter:
```
apps/mobile/lib/
    services/financial_core/
        arbitrage_engine.dart
        arbitrage_models.dart
    screens/arbitrage/
        rente_vs_capital_screen.dart
        allocation_annuelle_screen.dart
    widgets/
        trajectory_comparison_chart.dart   # Side-by-side curves
        hypothesis_editor_widget.dart      # User modifies assumptions
        breakeven_indicator_widget.dart     # Crossover point display
```

**Spec — Rente vs Capital**:

THREE options always shown (not two):
- Option A: Full rente (taxed as income annually, LIFD art. 22)
- Option B: Full capital (taxed once at withdrawal, LIFD art. 38, SWR strategy)
- Option C: Mixed — obligatoire as rente (6.8%), surobligatoire as capital

Must show: breakeven age, cumulative tax differential, inheritance impact.
Must allow: modification of rendement, SWR rate, life expectancy.

Critical calculation:
```
The 6.8% conversion on obligatoire = implicit guaranteed return of ~4-5%.
This MUST be surfaced to the user as educational insight.
"Pour chaque CHF 100'000 en LPP obligatoire, tu reçois CHF 6'800/an
 garanti à vie. Aucun placement sans risque n'offre ce rendement."
```

**Spec — Allocation Annuelle**:

Up to 4 options compared on same horizon, same starting amount:
1. 3a (if not maxed): deduction + projected growth at conservative rate
2. Rachat LPP (if eligible + marginal > 25%): deduction + LPP rate + withdrawal tax
3. Amortissement indirect (if property): tax optimization on mortgage deduction
4. Investissement libre: market return, no deduction, full liquidity

Display: 4 trajectories on one chart. Breakeven points. Sensitivity toggle.

**Compliance — ALL arbitrage screens**:
- No ranking. Side-by-side only.
- Hypotheses visible and editable by user.
- Sensitivity shown: "Si le rendement passe de X% à Y%, le résultat s'inverse."
- Conditional language: "Dans ce scénario simulé..."
- Disclaimer + sources on every screen.

---

### S33 — Arbitrage Phase 2 + Longitudinal Snapshots

**Goal**: Complete the arbitrage suite. Start tracking user state over time.

**Deliverables**:

Arbitrage additions:
```
services/backend/app/services/arbitrage/
    location_vs_propriete.py
    rachat_vs_marche.py
    calendrier_retraits.py
    tests/test_location_vs_propriete.py    # Min 15 tests
    tests/test_rachat_vs_marche.py         # Min 15 tests
    tests/test_calendrier_retraits.py      # Min 15 tests
```

Snapshot system:
```
services/backend/app/services/snapshots/
    snapshot_service.py
    snapshot_models.py
    tests/test_snapshots.py               # Min 10 tests
```

**Spec — Calendrier de Retraits** (highest wow-number potential):

Inputs: list of retirement assets (3a accounts × N, LPP, libre passage)
Each asset has: type, amount, earliest withdrawal age.

Compare:
- Option A: Withdraw everything same year
- Option B: Optimally staggered (3a at 60, LPP at 63, spouse at 64, etc.)

Uses TaxCalculator.capitalWithdrawalTax() with progressive brackets.

The chiffre choc: "En étalant tes retraits sur X ans, tu économises CHF Y d'impôt."

This is often CHF 15'000-40'000+ for middle-class Swiss households.
It's the single most underknown optimization.

**Spec — Snapshots**:

```sql
CREATE TABLE financial_snapshots (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL,
    created_at TIMESTAMP NOT NULL,
    trigger TEXT NOT NULL,          -- quarterly | life_event | profile_update | check_in
    model_version TEXT NOT NULL,

    -- Inputs at time of snapshot
    age INT,
    gross_income FLOAT,
    canton TEXT,
    archetype TEXT,

    -- Computed outputs (from financial_core)
    replacement_ratio FLOAT,
    months_liquidity FLOAT,
    tax_saving_potential FLOAT,
    fri_total FLOAT,
    confidence_score FLOAT,

    -- Metadata
    enrichment_count INT
);
```

Triggers: quarterly auto + on check-in + on life event + on profile update.
Privacy: encrypted at rest, explicit consent required, user can delete all.

---

## TRACK B — COACH LAYER (LLM-Powered, BYOK)

### S34 — Compliance Guard (BEFORE any LLM integration)

**Goal**: Build the safety net before turning on the LLM.
This sprint produces zero user-visible features. It produces the infrastructure
that makes all subsequent LLM features legally safe.

**This is non-negotiable. No LLM text reaches the user without passing through this.**

**Deliverables**:

```
apps/mobile/lib/services/coach/
    compliance_guard.dart          # Validates ALL LLM output before display
    hallucination_detector.dart    # Verifies numbers against financial_core
    prompt_registry.dart           # Versioned system prompts
    coach_models.dart              # Shared types

services/backend/app/services/coach/
    compliance_guard.py            # Backend mirror
    hallucination_detector.py
    prompt_registry.py
    tests/test_compliance_guard.py     # Min 25 tests (adversarial)
    tests/test_hallucination.py        # Min 15 tests
```

**Spec — ComplianceGuard**:

```dart
class ComplianceGuard {
  /// Validates LLM output. Returns sanitized text or triggers fallback.
  ComplianceResult validate(String llmOutput, CoachContext context);
}

class ComplianceResult {
  final bool isCompliant;
  final String sanitizedText;     // Cleaned version (if salvageable)
  final List<String> violations;  // What failed
  final bool useFallback;         // If true, discard LLM output entirely
}
```

Validation layers (ALL must pass):

```
Layer 1 — Banned Terms Check
  Regex scan for ALL banned terms from CLAUDE.md:
  "garanti", "certain", "assuré", "sans risque",
  "optimal", "meilleur", "parfait",
  "conseiller" (→ must be "spécialiste"),
  "tu devrais", "tu dois", "il faut que tu",
  "la meilleure option", "nous recommandons"

  If found → attempt replacement. If >2 violations → fallback.

Layer 2 — Prescriptive Language Check
  Detect imperative mood directed at financial action:
  "fais un rachat", "verse sur ton 3a", "achète", "vends",
  "choisis la rente", "prends le capital"

  Any prescriptive financial instruction → fallback.

Layer 3 — Number Verification (HallucinationDetector)
  Extract all CHF amounts and percentages from LLM output.
  Compare against CoachContext (which contains financial_core outputs).
  Tolerance: ±5% for amounts, ±2 points for percentages.

  If ANY number deviates beyond tolerance → fallback.

Layer 4 — Disclaimer Injection
  If output discusses financial projections/simulations AND
  does not contain a disclaimer → append standard disclaimer.

Layer 5 — Length Check
  greeting: max 30 words
  scoreSummary: max 80 words
  tip: max 120 words
  chiffreChoc narrative: max 100 words
  scenarioNarration: max 150 words per scenario

  If exceeded → truncate at last complete sentence.
```

**Spec — HallucinationDetector**:

```dart
class HallucinationDetector {
  /// Extracts numbers from LLM text, compares against known values.
  /// Returns list of hallucinated numbers (if any).
  List<HallucinatedNumber> detect(
    String llmOutput,
    Map<String, double> knownValues,  // e.g. {"score": 62, "3a_saving": 1820}
  );
}
```

Regex pattern for Swiss financial numbers:
```
CHF\s*[\d']+          → amounts
\d+[.,]\d+\s*%        → percentages
\d+\s*(mois|ans|CHF)  → durations and amounts
```

**Spec — PromptRegistry**:

Every system prompt is versioned, stored in code, never generated dynamically.

```dart
class PromptRegistry {
  static const String version = "1.0.0";

  /// Base system prompt for ALL coach interactions.
  static const String baseSystemPrompt = '''
Tu es le coach financier de MINT, une application éducative suisse.

RÈGLES ABSOLUES :
- Tu ne donnes JAMAIS de conseil. Tu expliques des simulations.
- Tu ne dis JAMAIS "tu devrais", "il faut", "la meilleure option".
- Tu utilises TOUJOURS le conditionnel : "pourrait", "dans ce scénario".
- Tu MENTIONNES TOUJOURS l'incertitude.
- Les chiffres que tu cites doivent correspondre EXACTEMENT aux données fournies.
- Tu ne JAMAIS inventer de chiffre.
- Tu tutoies l'utilisateur.
- Tu es bienveillant mais jamais paternaliste.
- Tu ne compares JAMAIS l'utilisateur à d'autres personnes.

TERMES INTERDITS (ne les utilise JAMAIS) :
garanti, certain, assuré, sans risque, optimal, meilleur, parfait,
conseiller (utilise "spécialiste"), tu devrais, tu dois, il faut

FORMAT :
- Phrases courtes (max 20 mots).
- Un paragraphe = une idée.
- Toujours ancrer sur un chiffre concret du profil.
''';

  /// Prompt for dashboard greeting
  static String dashboardGreeting(CoachContext ctx) => '''
$baseSystemPrompt

CONTEXTE UTILISATEUR :
- Prénom : ${ctx.firstName}
- Score actuel : ${ctx.friTotal}/100
- Variation depuis dernier check-in : ${ctx.friDelta}
- Priorité actuelle : ${ctx.primaryFocus}
- Jours depuis dernière visite : ${ctx.daysSinceLastVisit}
- Date : ${ctx.today}
- Saison fiscale : ${ctx.fiscalSeason}

TÂCHE : Génère un greeting de 1-2 phrases (max 30 mots).
Mentionne le score ou la variation si pertinent.
Si deadline fiscale proche, mentionne-la.
''';

  // ... similar for each component (scoreSummary, tip, chiffreChoc, etc.)
}
```

**Test requirements** (adversarial):
- Feed compliance guard with 25+ examples of non-compliant LLM outputs
- Verify each is caught or sanitized
- Test hallucination detector with deliberately wrong numbers
- Test edge cases: empty output, extremely long output, output in wrong language
- Test that fallback templates are always valid

---

### S35 — Coach Narrative Service (T1 + T2 + T3)

**Goal**: Dashboard becomes alive. Tips become personal. Chiffre choc becomes emotional.

**Prerequisite**: S34 (ComplianceGuard) MUST be complete and passing all tests.

**Deliverables**:

```
apps/mobile/lib/services/coach/
    coach_narrative_service.dart    # Orchestrates LLM calls
    coach_context_builder.dart     # Builds context from profile + financial_core
    coach_cache_service.dart       # Smart invalidation cache
    fallback_templates.dart        # Static alternatives (no BYOK)

apps/mobile/lib/screens/dashboard/
    coach_pulse_card.dart          # Replaces static pulse with coach narrative
    coach_tip_card.dart            # Narrative tips
    coach_chiffre_choc_card.dart   # Emotional chiffre choc
```

**Architecture — NOT a single LLM call**:

```
┌─────────────────────────────────────────────────┐
│              CoachNarrativeService               │
│                                                   │
│  Input: CoachContext (built from financial_core)  │
│                                                   │
│  Call 1: greeting          → ComplianceGuard → ✓ │
│  Call 2: scoreSummary      → ComplianceGuard → ✓ │
│  Call 3: tipNarrative      → ComplianceGuard → ✓ │
│  Call 4: chiffreChocReframe→ ComplianceGuard → ✓ │
│                                                   │
│  Each call: independent cache, independent        │
│  fallback, independent compliance check.          │
│                                                   │
│  If Call 2 fails → fallback for Call 2 only.     │
│  Calls 1,3,4 still show LLM content.             │
└─────────────────────────────────────────────────┘
```

Why 4 calls instead of 1:
- Independent failure (greeting can fail without killing scoreSummary)
- Independent caching (greeting changes daily, scoreSummary changes on check-in)
- Independent compliance (a tip violation doesn't discard the greeting)
- Parallel execution (4 small calls faster than 1 large call)

**Spec — CoachContext**:

```dart
class CoachContext {
  // Identity
  final String firstName;
  final String archetype;
  final int age;
  final String canton;

  // Financial state (from financial_core — NEVER raw user data)
  final double friTotal;
  final double friDelta;          // vs last snapshot
  final String primaryFocus;       // from AdaptivePriorityService
  final double replacementRatio;
  final double monthsLiquidity;
  final double taxSavingPotential;
  final double confidenceScore;

  // Temporal
  final DateTime today;
  final int daysSinceLastVisit;
  final String? fiscalSeason;     // "3a_deadline", "tax_declaration", null
  final String? upcomingEvent;    // "retirement_5y", "buyback_expiry", null

  // Behavioral
  final int checkInStreak;
  final String? lastMilestone;

  // NEVER included (privacy):
  // - exact salary amount
  // - exact savings amount
  // - exact debt amount
  // - NPA / address
  // - employer name
  // Instead: ratios, categories, ranges
}
```

**What is sent to LLM vs what is NOT**:

```
✅ SENT (aggregated / anonymized):
- firstName (user consented)
- age, canton, archetype
- FRI score and components (0-100 scale)
- replacement ratio (percentage)
- months of liquidity (number)
- tax saving potential (CHF amount — this IS personal but essential)
- calendar context

❌ NEVER SENT:
- exact gross salary
- exact savings balance
- exact debt amounts
- bank names, account numbers
- employer name
- NPA, address
- family members' names
```

**Spec — Smart Cache**:

```dart
class CoachCacheService {
  /// Cache key = component + context hash
  /// Invalidation triggers:
  ///   - check_in completed → invalidate scoreSummary, tipNarrative
  ///   - profile updated → invalidate ALL
  ///   - new day → invalidate greeting only
  ///   - arbitrage completed → invalidate chiffreChocReframe
  ///   - manual refresh → invalidate ALL

  Future<String?> get(String component, String contextHash);
  Future<void> set(String component, String contextHash, String content, Duration ttl);
  Future<void> invalidate(InvalidationTrigger trigger);
}

enum InvalidationTrigger {
  checkIn,
  profileUpdate,
  newDay,
  arbitrageCompleted,
  manualRefresh,
}
```

Default TTLs:
- greeting: 24h (or until newDay)
- scoreSummary: until next check-in
- tipNarrative: 7 days
- chiffreChocReframe: until profile change

**Spec — Fallback Templates** (without BYOK):

NOT the current static templates. Enhanced templates that use the same
CoachContext to produce personalized (but non-LLM) text.

```dart
class FallbackTemplates {
  static String greeting(CoachContext ctx) {
    if (ctx.daysSinceLastVisit == 0) return "Bon retour, ${ctx.firstName}.";
    if (ctx.daysSinceLastVisit < 7) return "Content de te revoir, ${ctx.firstName}.";
    if (ctx.fiscalSeason == "3a_deadline") {
      return "${ctx.firstName}, il reste ${ctx.daysTo3aDeadline} jours pour ton 3a.";
    }
    return "Salut ${ctx.firstName}. Ton score de solidité : ${ctx.friTotal}/100.";
  }

  static String scoreSummary(CoachContext ctx) {
    String trend = ctx.friDelta > 0
      ? "En progression de ${ctx.friDelta} points."
      : ctx.friDelta < 0
        ? "En recul de ${ctx.friDelta.abs()} points."
        : "Stable.";
    return "Solidité financière : ${ctx.friTotal}/100. $trend";
  }

  // ... etc for each component
}
```

These fallback templates:
- Use CoachContext (so they're personal)
- Are deterministic (no LLM, no compliance risk)
- Are hardcoded (no prompt injection possible)
- Are reviewed for compliance at code review time
- Serve as the MINIMUM quality bar (LLM output must be better than this)

---

### S36 — Notifications + Milestones (T4 + T5)

**Goal**: MINT reaches out to the user. MINT celebrates progress.

**Deliverables**:

```
apps/mobile/lib/services/
    notification_scheduler_service.dart    # Local notification scheduling
    milestone_detection_service.dart       # Detects milestones on check-in
    milestone_celebration_service.dart     # Triggers celebration UX

apps/mobile/lib/screens/
    milestone_celebration_sheet.dart       # Bottom sheet with animation
```

**Spec — Notifications** (3 tiers):

Tier 1 — Calendar-driven (scheduled at app launch):
```
Oct 1:   "Il reste 92 jours pour verser sur ton 3a."
Nov 1:   "Il reste 61 jours. Économie estimée : CHF {taxSaving3a}."
Dec 1:   "Dernier mois pour ton 3a. CHF {taxSaving3a} d'économie en jeu."
Dec 20:  "11 jours. Dernier rappel 3a."
Jan 5:   "Nouveaux plafonds 2027. Ton économie potentielle a changé."
Monthly: "Ton check-in mensuel est disponible."
```

Tier 2 — Event-driven (on app resume via WidgetsBindingObserver):
```
If check-in completed since last visit → "Depuis ton dernier check-in : +{delta} points."
If profile updated → "Ton profil a été mis à jour. Nouvelles projections disponibles."
If FRI improved → "Ta solidité a progressé de {delta} points ce trimestre."
```

Tier 3 — BYOK-enriched (generated by CoachNarrativeService if BYOK active):
```
Same triggers as Tier 1-2, but notification text generated by LLM.
Still passes through ComplianceGuard.
Fallback to Tier 1-2 text if compliance fails.
```

Every notification MUST contain:
- A personal number (CHF or percentage)
- A time reference (deadline, duration, period)
- A deeplink to the relevant screen

Every notification MUST NOT contain:
- Generic encouragement ("Reviens nous voir!")
- Social comparison ("Tu es en retard par rapport à...")
- Prescriptive language ("Tu dois verser...")

**Spec — Milestones**:

Detected milestones (compared against previous snapshot):

```dart
enum MilestoneType {
  emergencyFund3Months,
  emergencyFund6Months,
  threeeAMaxReached,
  lppBuybackCompleted,
  friImproved10Points,
  friAbove50,
  friAbove70,
  friAbove85,
  patrimoine50k,
  patrimoine100k,
  patrimoine250k,
  firstArbitrageCompleted,
  checkInStreak6Months,
  checkInStreak12Months,
}
```

Celebration: bottom sheet with animation (confetti package) + message.

Without BYOK:
```
"Plafond 3a atteint — CHF 7'258. Économie fiscale estimée : ~CHF {saving}."
```

With BYOK: LLM generates celebration text → ComplianceGuard → display.

**Compliance rule for milestones**:
- NEVER use social comparison ("top 20% des Suisses" → BANNED)
- NEVER guarantee future outcomes ("tu es sécurisé" → BANNED)
- Always factual: what was achieved, what it means concretely

---

### S37 — Scenario Narration + Annual Refresh (T6 + T7)

**Goal**: Retirement scenarios become stories. Profiles stay fresh.

**Deliverables**:

```
apps/mobile/lib/services/
    scenario_narrator_service.dart     # Narrates Forecaster scenarios
    annual_refresh_service.dart        # Detects stale profiles, proposes refresh

apps/mobile/lib/screens/
    scenario_narration_screen.dart     # 3 scenarios as stories
    annual_refresh_flow.dart           # 7-question lightweight update
```

**Spec — Scenario Narration**:

After ForecasterService.project() returns 3 scenarios (prudent/base/optimiste):

Without BYOK:
```
Prudent (1%/an) : CHF {amount}. Rente estimée : CHF {monthly}/mois.
Base (4.5%/an) : CHF {amount}. Rente estimée : CHF {monthly}/mois.
Optimiste (7%/an) : CHF {amount}. Rente estimée : CHF {monthly}/mois.
```

With BYOK: LLM receives the 3 numbers + CoachContext → generates 3 paragraphs.
Each paragraph: max 150 words.
Each paragraph MUST mention the assumption (rendement) and the uncertainty.

ComplianceGuard verifies:
- All 3 CHF amounts match ForecasterService output (±5%)
- No prescriptive language
- Uncertainty mentioned in each paragraph
- No "guaranteed", "certain", "assured"

**Spec — Annual Refresh**:

Detection: profile.lastMajorUpdate > 11 months ago.

Flow (7 questions, pre-filled with current values):
1. "Ton salaire a-t-il changé ?" → slider pre-filled
2. "As-tu changé d'emploi ?" → yes/no
3. "Ton avoir LPP actuel ?" → text field + help: "regarde ton certificat de prévoyance"
4. "Solde 3a approximatif ?" → pre-filled with projection
5. "Nouveau projet immobilier ?" → yes/no
6. "Changement familial ?" → marriage/birth/divorce/none
7. "Ton appétit au risque a-t-il changé ?" → conservateur/modéré/dynamique

After refresh:
- Full recalculation via financial_core
- New snapshot stored
- FRI delta displayed
- If improvement → milestone celebration

---

## TRACK C — ENGAGEMENT LOOP

### S38 — FRI (Shadow Mode)

**Goal**: FRI computed on every check-in and snapshot, but NOT displayed to users.
Purpose: validate calibration, identify edge cases, tune weights.

**Deliverables**:

```
apps/mobile/lib/services/financial_core/
    fri_calculator.dart           # Pure function, uses existing calculators

services/backend/app/services/fri/
    fri_service.py
    tests/test_fri.py             # Min 20 tests including archetype variations
```

FRI logged in snapshots. Analytics tracked internally.
Calibration review after 4 weeks of shadow data.

---

### S39 — FRI (Beta Display) + Longitudinal Charts

**Goal**: FRI visible to users. Historical progression chart.

**Prerequisite**: Shadow mode data validated. No extreme outliers or nonsensical scores.

**Deliverables**:

```
apps/mobile/lib/
    screens/fri/
        fri_dashboard_card.dart        # Score + breakdown + top action
        fri_history_chart.dart         # 6-12 month progression
    widgets/
        fri_breakdown_bars.dart        # 4 horizontal bars (L, F, R, S)
        fri_action_suggestion.dart     # Top action to improve FRI
```

API:
```
GET  /api/v1/fri/current          → FriBreakdown
GET  /api/v1/fri/history          → List<FriBreakdown>
POST /api/v1/fri/simulate-action  → { deltaFri, newBreakdown }
```

Display rules:
- Only shown if confidenceScore >= 50%
- Always show breakdown (never total alone)
- Always show top improvement action with estimated delta
- Never say "faible", "mauvais", "insuffisant"
- Never compare to other users

---

### S40 — Reengagement Engine + Consent Hardening

**Goal**: MINT reaches out at the right time with the right number.
Also: ensure all data flows have proper consent.

**Deliverables**:

```
apps/mobile/lib/services/
    reengagement_engine.dart       # Decides what to send when
    consent_manager.dart           # Granular consent for each data flow

apps/mobile/lib/screens/
    consent_dashboard_screen.dart  # User sees exactly what is shared where
```

**Spec — Consent Dashboard**:

User must explicitly consent to:
1. BYOK: "Envoyer mes données financières agrégées à [provider] pour personnalisation"
   - Shows exactly which data is sent (CoachContext fields)
   - Shows which data is NEVER sent
   - Provider name displayed (Claude / OpenAI / Mistral)
2. Snapshots: "Conserver l'historique de mes projections pour suivre ma progression"
3. Notifications: "Recevoir des rappels personnalisés (3a, impôts, check-in)"

Each consent is independent. User can enable BYOK but disable snapshots.
All consents revocable at any time with immediate effect.

---

## CONSOLIDATED TEST REQUIREMENTS

| Sprint | Backend Tests | Flutter Tests | Compliance Tests |
|--------|-------------|---------------|-----------------|
| S31 | 35+ | 10 smoke | 24 profile combos |
| S32 | 30+ | 10 smoke | Wording check all outputs |
| S33 | 45+ | 10 smoke | Wording check all outputs |
| S34 | 40+ | 0 (infra only) | 25 adversarial LLM outputs |
| S35 | 15+ | 15 smoke | Fallback vs LLM parity check |
| S36 | 15+ | 10 smoke | Notification wording check |
| S37 | 20+ | 10 smoke | Scenario narration compliance |
| S38 | 20+ | 0 (shadow) | FRI calibration on known profiles |
| S39 | 10+ | 10 smoke | FRI display compliance |
| S40 | 10+ | 10 smoke | Consent flow completeness |

**Baseline rule**: ALL existing tests must still pass at every sprint.
`flutter analyze` = 0 errors at every sprint.

---

## CRITICAL ARCHITECTURE DECISIONS

### Decision 1: Multiple LLM calls, not one

4 independent calls (greeting, scoreSummary, tip, chiffreChoc) instead of 1 monolithic call.
Rationale: independent failure, independent cache, independent compliance, parallel execution.

### Decision 2: Compliance Guard BEFORE Coach Layer

S34 (ComplianceGuard) ships before S35 (CoachNarrativeService).
No LLM output ever reaches a user without passing through the guard.

### Decision 3: FRI in shadow mode first

S38 computes FRI without displaying it. S39 displays after calibration review.
Rationale: a miscalibrated score destroys trust.

### Decision 4: CoachContext, not raw profile

The LLM never sees raw financial amounts (salary, savings, debt).
It sees ratios, scores, categories, and ranges.
Exception: tax saving potential (CHF amount needed for meaningful coaching).

### Decision 5: Fallback templates are first-class citizens

Without BYOK, the app uses enhanced templates (not current static text).
These templates use CoachContext for personalization.
They are the minimum quality bar — LLM output must exceed this.

### Decision 6: No social comparison

Milestones, FRI, and coaching never compare the user to others.
"Top 20% des Suisses" → BANNED.
Only compare user to their own past: "Tu as progressé de X points."

### Decision 7: Arbitrage before Coach Layer

Track A (onboarding + arbitrage) ships before Track B (LLM coaching).
Rationale: arbitrage adds functional value without LLM dependency.
Coach Layer enhances existing value — it doesn't create it.

---

## DEPENDENCY GRAPH

```
S31 (Onboarding)
 ├── S32 (Arbitrage Phase 1)
 │    └── S33 (Arbitrage Phase 2 + Snapshots)
 │         └── S38 (FRI Shadow)
 │              └── S39 (FRI Beta)
 │
 └── S34 (Compliance Guard)         ← BLOCKER for all LLM features
      ├── S35 (Coach Narrative)
      │    └── S36 (Notifications + Milestones)
      │         └── S37 (Scenarios + Refresh)
      │
      └── S40 (Reengagement + Consent)
```

S34 (ComplianceGuard) is the critical path blocker.
Nothing in Track B ships without it.

---

## WHAT THIS PLAN DOES NOT INCLUDE (deliberately)

1. **Monte Carlo simulation** — Current 3-scenario approach (Bas/Moyen/Haut) is honest
   and comprehensible. Monte Carlo adds precision but not clarity. Defer to V3.

2. **BYOK marketplace / premium prompts** — Premature optimization. Get the base
   coaching right first.

3. **Backend push notifications** — Start with local notifications only.
   Backend push requires infrastructure (FCM/APNs) and introduces privacy complexity.

4. **AI-generated PDF reports** — Valuable but not on the critical path.
   Defer to after FRI is stable.

5. **Multi-device sync of coach cache** — Local only for now.
   Sync adds complexity without proportional user value.

---

## SUCCESS METRICS

| Metric | Current | Target (6 months) | How measured |
|--------|---------|-------------------|-------------|
| Onboarding completion rate | unknown | > 70% | 3 questions completed |
| Time to first chiffre choc | unknown | < 60 seconds | From app open to chiffre choc |
| Check-in retention (monthly) | unknown | > 40% | Monthly active check-ins |
| Arbitrage usage | 0 | > 25% of active users | Any arbitrage simulation completed |
| FRI improvement | N/A | > 30% of users improve over 6 months | Snapshot comparison |
| BYOK activation (of eligible) | unknown | > 50% | BYOK key configured |
| Notification opt-in | 0 | > 60% | Consent dashboard |

---

*Document version: 1.0 — February 2026*
*Status: Approved for sprint planning*
*Dependencies: CLAUDE.md (constants), ONBOARDING_ARBITRAGE_ENGINE.md (specs)*
