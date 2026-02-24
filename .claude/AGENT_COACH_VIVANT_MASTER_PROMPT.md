# AGENT_COACH_VIVANT_MASTER_PROMPT.md
# Master Execution Prompt — MINT Coach Vivant Implementation
# For Claude Code Opus 4.6 Agent Team

---

## CONTEXT

You are a team of senior engineers building MINT, the Swiss financial coaching app.
You are executing the "Coach Vivant" evolution: transforming MINT from a static calculator
into a living financial coach.

**Before writing ANY code, you MUST read these documents IN THIS ORDER:**

```
1. .claude/CLAUDE.md                          — Project bible. Constants. Compliance. Anti-patterns.
2. docs/ONBOARDING_ARBITRAGE_ENGINE.md        — Onboarding + Arbitrage + FRI + Adaptive UX specs
3. docs/MINT_COACH_VIVANT_ROADMAP.md          — Master execution plan. Sprint breakdown. Dependencies.
4. decisions/ADR-20260223-unified-financial-engine.md  — Financial core architecture
5. decisions/ADR-20260223-archetype-driven-retirement.md — Archetype system
```

**If you have not read all 5 documents, STOP. Read them now. Do not proceed.**

---

## YOUR IDENTITY

You are Silicon Valley / Zurich senior engineers with deep expertise in:
- Flutter + Dart (production mobile apps)
- FastAPI + Python (financial services backends)
- Swiss fiscal law (LPP, LAVS, LIFD, OPP3, LSFin, LAMal, nLPD)
- CFA-level financial modeling
- Compliance-first fintech architecture
- LLM integration with safety guardrails

You treat CLAUDE.md as sacred law. Every constant, every banned term, every anti-pattern
is non-negotiable. If this prompt contradicts CLAUDE.md, CLAUDE.md wins.

---

## EXECUTION MODEL

### Team Structure

```
LEAD AGENT        — Reads all docs. Plans sprint. Spawns specialists. Reviews output.
BACKEND AGENT     — Python services + tests. Backend = source of truth.
FLUTTER AGENT     — Dart services + screens + widgets. Mirrors backend exactly.
COMPLIANCE AGENT  — Reviews ALL user-facing text. Checks banned terms. Validates disclaimers.
```

### Sprint Execution Protocol

For EACH sprint:

```
Step 1: LEAD reads sprint spec from MINT_COACH_VIVANT_ROADMAP.md
Step 2: LEAD reads corresponding detailed spec from ONBOARDING_ARBITRAGE_ENGINE.md
Step 3: LEAD reads existing code that will be touched (ALWAYS read before write)
Step 4: LEAD spawns BACKEND AGENT with precise spec
Step 5: LEAD spawns FLUTTER AGENT with precise spec
Step 6: Both agents complete independently
Step 7: LEAD runs ALL tests (backend + flutter analyze)
Step 8: LEAD spawns COMPLIANCE AGENT to review all user-facing strings
Step 9: LEAD fixes any divergence (backend = source of truth)
Step 10: LEAD commits surgically (only sprint files)
```

---

## SPRINT SPECS

### ═══════════════════════════════════════
### S31 — ONBOARDING REDESIGN
### ═══════════════════════════════════════

**Read first**: ONBOARDING_ARBITRAGE_ENGINE.md § II (Onboarding Redesign)

**BACKEND AGENT SPEC:**

Create these files:
```
services/backend/app/services/onboarding/__init__.py
services/backend/app/services/onboarding/minimal_profile_service.py
services/backend/app/services/onboarding/chiffre_choc_selector.py
services/backend/app/services/onboarding/onboarding_models.py
services/backend/app/api/v1/endpoints/onboarding.py
services/backend/tests/test_minimal_profile.py
services/backend/tests/test_chiffre_choc.py
```

**minimal_profile_service.py:**

```python
from dataclasses import dataclass
from typing import Optional

@dataclass
class MinimalProfileInput:
    age: int
    gross_salary: float
    canton: str
    # Optional enrichment (None = use defaults)
    household_type: Optional[str] = None        # default: "single"
    current_savings: Optional[float] = None      # default: estimated
    is_property_owner: Optional[bool] = None     # default: False
    existing_3a: Optional[float] = None          # default: 0
    existing_lpp: Optional[float] = None         # default: estimated

@dataclass
class MinimalProfileResult:
    # Computed values
    projected_avs_monthly: float
    projected_lpp_capital: float
    projected_lpp_monthly: float
    estimated_replacement_ratio: float
    estimated_monthly_retirement: float
    estimated_monthly_expenses: float
    tax_saving_3a: float
    marginal_tax_rate: float
    months_liquidity: float
    # Metadata
    confidence_score: float
    estimated_fields: list[str]      # Which fields used defaults
    archetype: str
    disclaimer: str
    sources: list[str]
```

MUST use existing calculators from `app/services/` that mirror `financial_core/`.
NEVER reimplement AVS, LPP, or tax logic.

Default estimation logic:
- `current_savings`: `max(0, (age - 25) * gross_salary * 0.05)`
- `monthly_expenses`: `net_salary * 0.85`
- `household_type`: `"single"`
- `existing_lpp`: project from age 25 using LPP bonification rates from CLAUDE.md

**chiffre_choc_selector.py:**

Priority order (select FIRST match):
1. `months_liquidity < 2` → category "liquidity", display: months of runway
2. `replacement_ratio < 0.55` → category "retirement_gap", display: monthly gap
3. `existing_3a == 0 AND tax_saving_3a > 1500` → category "tax_saving", display: annual saving
4. `lpp_buyback_potential > 20000 AND marginal_tax_rate > 0.25` → category "lpp_opportunity"
5. `mortgage_stress > 0.38` → category "mortgage_stress"

Returns exactly ONE ChiffreChoc. Never two.

```python
@dataclass
class ChiffreChoc:
    category: str
    primary_number: float
    display_text: str              # French, informal "tu"
    explanation_text: str
    action_text: str
    disclaimer: str                # ALWAYS present
    sources: list[str]
    confidence_score: float
```

**Tests (test_minimal_profile.py — min 20 tests):**
- Test all 8 archetypes × at least 2 age bands
- Test with all optional fields None (pure minimal)
- Test with all optional fields provided (full enrichment)
- Test that estimated_fields correctly lists defaulted fields
- Test that confidence_score < 50 when only 3 inputs
- Test that confidence_score > 70 when all fields provided
- Test that disclaimer is always non-empty
- Test that sources always contain at least one legal reference

**Tests (test_chiffre_choc.py — min 15 tests):**
- Test priority ordering: liquidity crisis beats retirement gap
- Test each category triggers correctly
- Test that exactly one chiffre choc is returned
- Test banned terms not present in any display_text
- Test edge cases: age 22, age 64, salary 0, salary 500k
- Compliance check: no "garanti", "optimal", "meilleur", "tu devrais" in ANY output string

**API endpoint (onboarding.py):**
```
POST /api/v1/onboarding/minimal-profile
POST /api/v1/onboarding/chiffre-choc
```

Pydantic schemas with `alias_generator = to_camel`, `populate_by_name = True`.

---

**FLUTTER AGENT SPEC:**

Create these files:
```
apps/mobile/lib/services/minimal_profile_service.dart
apps/mobile/lib/services/chiffre_choc_selector.dart
apps/mobile/lib/models/minimal_profile_models.dart
apps/mobile/lib/screens/onboarding/onboarding_minimal_screen.dart
apps/mobile/lib/screens/onboarding/chiffre_choc_screen.dart
apps/mobile/lib/screens/onboarding/progressive_enrichment_screen.dart
```

**MUST import `financial_core.dart`** for all calculations. NEVER create private
`_calculateAvs()`, `_estimateLpp()`, or similar methods. Use:
- `AvsCalculator.computeMonthlyRente()`
- `LppCalculator.projectToRetirement()`
- `TaxCalculator.estimateMonthlyIncomeTax()`
- `ConfidenceScorer.score()`

**onboarding_minimal_screen.dart:**
- 3 inputs only: salary (slider), age (picker), canton (dropdown)
- Salary slider presets: 50k, 60k, 80k, 100k, 120k, 150k+
- Canton dropdown: 26 cantons sorted alphabetically
- Single CTA button: "Voir mon résultat"
- No navigation to other modules until chiffre choc is shown

**chiffre_choc_screen.dart:**
- Full-screen card with ONE number (large, centered)
- Contextual subtitle (e.g., "Aujourd'hui, tu dépenses probablement ~CHF X/mois")
- Confidence indicator: "Estimation basée sur 3 informations."
- Two CTAs: "Qu'est-ce que je peux faire?" + "Affiner mon profil"
- Design: MintColors, Montserrat heading, Inter body, Material 3

**progressive_enrichment_screen.dart:**
- Additional questions in rounds (Round 2: family/savings/property, Round 3: 3a/LPP/debt)
- Each answer triggers real-time recalculation of chiffre choc
- Animated transition showing number changing
- User can stop at any point and proceed to main app

**Design rules (from CLAUDE.md):**
- Fonts: GoogleFonts — Montserrat (headings), Inter (body)
- Colors: MintColors from lib/theme/colors.dart
- Navigation: GoRouter
- State: Provider
- Material 3
- All text in French, informal "tu", inclusive language

---

### ═══════════════════════════════════════
### S32 — ARBITRAGE PHASE 1 (Rente vs Capital + Allocation Annuelle)
### ═══════════════════════════════════════

**Read first**: ONBOARDING_ARBITRAGE_ENGINE.md § III (Arbitrage Transparency Engine)

**BACKEND AGENT SPEC:**

Create:
```
services/backend/app/services/arbitrage/__init__.py
services/backend/app/services/arbitrage/arbitrage_engine.py
services/backend/app/services/arbitrage/arbitrage_models.py
services/backend/app/services/arbitrage/rente_vs_capital.py
services/backend/app/services/arbitrage/allocation_annuelle.py
services/backend/app/api/v1/endpoints/arbitrage.py
services/backend/tests/test_rente_vs_capital.py
services/backend/tests/test_allocation_annuelle.py
```

**CRITICAL — Rente vs Capital must ALWAYS show 3 options:**
- Option A: Full rente (taxed as income, LIFD art. 22)
- Option B: Full capital (taxed once, LIFD art. 38, then SWR)
- Option C: Mixed — obligatoire as rente (6.8%), surobligatoire as capital

The mixed scenario is the key differentiator. Most Swiss fintechs only show A vs B.

**CRITICAL — Allocation Annuelle compares up to 4 options:**
- 3a (if not maxed): plafond 7'258 CHF (CLAUDE.md constant)
- Rachat LPP (if eligible): check blocage 3 ans (LPP art. 79b al. 3)
- Amortissement indirect (if property owner)
- Investissement libre (always available)

Same horizon, same starting amount, 4 trajectories.

**Compliance rules for ALL arbitrage outputs:**
- NEVER rank options. Side by side only.
- hypotheses: list[str] ALWAYS populated and explicit
- sensitivity: dict[str, float] showing impact of ±1% on key parameter
- disclaimer ALWAYS present
- sources ALWAYS present
- breakevenYear calculated when trajectories cross
- conditional language: "Dans ce scénario simulé..."

**Tests (min 15 per module):**
- Test breakeven calculation accuracy
- Test mixed scenario produces different result than pure A or B
- Test sensitivity: changing rendement by 1% must change result
- Test compliance: no banned terms in ANY output string
- Test edge cases: age 64 (1 year to retirement), age 25 (40 years), capital 0
- Test that sources contain correct legal references
- Test that disclaimer is always non-empty

---

**FLUTTER AGENT SPEC:**

Create:
```
apps/mobile/lib/services/financial_core/arbitrage_engine.dart
apps/mobile/lib/services/financial_core/arbitrage_models.dart
apps/mobile/lib/screens/arbitrage/rente_vs_capital_screen.dart
apps/mobile/lib/screens/arbitrage/allocation_annuelle_screen.dart
apps/mobile/lib/widgets/arbitrage/trajectory_comparison_chart.dart
apps/mobile/lib/widgets/arbitrage/hypothesis_editor_widget.dart
apps/mobile/lib/widgets/arbitrage/breakeven_indicator_widget.dart
```

**trajectory_comparison_chart.dart:**
- CustomPainter chart showing 2-4 trajectories over time
- Color-coded lines (from MintColors)
- Crossover point highlighted with vertical dashed line + label
- X-axis: years. Y-axis: CHF (patrimoine net)
- Tap on any year shows exact values for all options

**hypothesis_editor_widget.dart:**
- Sliders for each modifiable hypothesis (rendement, inflation, SWR)
- Default values pre-filled
- Each slider change triggers real-time recalculation of chart
- Label showing current value + unit (e.g., "Rendement marché: 4.0%")

**breakeven_indicator_widget.dart:**
- Shows crossover year prominently
- If no crossover in horizon: "Les trajectoires ne se croisent pas sur cet horizon."
- Conditional text: "Si le rendement dépasse X%, le résultat s'inverse."

---

### ═══════════════════════════════════════
### S33 — ARBITRAGE PHASE 2 + SNAPSHOTS
### ═══════════════════════════════════════

**Read first**: ONBOARDING_ARBITRAGE_ENGINE.md § III (Modules C, D, E) + § VI (Snapshots)

**BACKEND AGENT SPEC:**

Create arbitrage additions:
```
services/backend/app/services/arbitrage/location_vs_propriete.py
services/backend/app/services/arbitrage/rachat_vs_marche.py
services/backend/app/services/arbitrage/calendrier_retraits.py
services/backend/tests/test_location_vs_propriete.py
services/backend/tests/test_rachat_vs_marche.py
services/backend/tests/test_calendrier_retraits.py
```

Create snapshot system:
```
services/backend/app/services/snapshots/__init__.py
services/backend/app/services/snapshots/snapshot_service.py
services/backend/app/services/snapshots/snapshot_models.py
services/backend/app/api/v1/endpoints/snapshots.py
services/backend/tests/test_snapshots.py
```

**Calendrier de Retraits — the highest wow-number potential:**

Input: List of retirement assets [{type: "3a"|"lpp"|"libre_passage", amount, earliest_withdrawal_age}]

Compare:
- Option A: Withdraw all same year at retirement age
- Option B: Staggered optimally (3a at 60, LPP at 63, spouse 3a at 64, etc.)

Use TaxCalculator.capitalWithdrawalTax() with progressive brackets from CLAUDE.md:
```
0-100k: base_rate × 1.00
100k-200k: base_rate × 1.15
200k-500k: base_rate × 1.30
500k-1M: base_rate × 1.50
1M+: base_rate × 1.70
```

The chiffre choc: total tax saved by staggering. Often CHF 15'000-40'000+.

**Snapshot table** (SQL or equivalent):
```sql
CREATE TABLE financial_snapshots (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    trigger TEXT NOT NULL,
    model_version TEXT NOT NULL,
    age INT, gross_income FLOAT, canton TEXT, archetype TEXT,
    replacement_ratio FLOAT, months_liquidity FLOAT,
    tax_saving_potential FLOAT,
    fri_total FLOAT, fri_l FLOAT, fri_f FLOAT, fri_r FLOAT, fri_s FLOAT,
    confidence_score FLOAT, enrichment_count INT
);
```

Snapshot triggers: "quarterly", "life_event", "profile_update", "check_in".

---

### ═══════════════════════════════════════
### S34 — COMPLIANCE GUARD (BLOCKER — before ANY LLM feature)
### ═══════════════════════════════════════

**Read first**: MINT_COACH_VIVANT_ROADMAP.md § S34

**THIS IS THE MOST CRITICAL SPRINT. NO LLM OUTPUT REACHES A USER WITHOUT THIS.**

**BACKEND AGENT SPEC:**

Create:
```
services/backend/app/services/coach/__init__.py
services/backend/app/services/coach/compliance_guard.py
services/backend/app/services/coach/hallucination_detector.py
services/backend/app/services/coach/prompt_registry.py
services/backend/app/services/coach/coach_models.py
services/backend/tests/test_compliance_guard.py
services/backend/tests/test_hallucination_detector.py
```

**compliance_guard.py — 5 validation layers:**

```python
class ComplianceGuard:
    BANNED_TERMS = [
        "garanti", "certain", "assuré", "sans risque",
        "optimal", "meilleur", "parfait",
        "conseiller",  # → use "spécialiste"
        "tu devrais", "tu dois", "il faut que tu",
        "la meilleure option", "nous recommandons", "nous te conseillons",
        "il est optimal", "la solution idéale",
    ]

    PRESCRIPTIVE_PATTERNS = [
        r"fais\s+un\s+rachat",
        r"verse\s+sur\s+ton",
        r"ach[eè]te",
        r"vends",
        r"choisis\s+la\s+rente",
        r"prends?\s+le\s+capital",
        r"investis?\s+dans",
        r"priorit[ée]\s+absolue",
        r"c['']est\s+plus\s+important\s+que",
    ]

    def validate(self, llm_output: str, context: dict) -> ComplianceResult:
        violations = []
        # Layer 1: Banned terms
        # Layer 2: Prescriptive patterns
        # Layer 3: Number verification (via HallucinationDetector)
        # Layer 4: Disclaimer presence check
        # Layer 5: Length check per component type
        ...
```

**hallucination_detector.py:**

```python
class HallucinationDetector:
    """Extracts numbers from LLM text, compares against known values."""

    CHF_PATTERN = r"CHF\s*[\d'']+(?:[.,]\d+)?"
    PCT_PATTERN = r"\d+[.,]\d+\s*%"
    DURATION_PATTERN = r"\d+\s*(?:mois|ans|semaines|jours)"

    def detect(self, llm_output: str, known_values: dict[str, float],
               tolerance_pct: float = 0.05, tolerance_abs: float = 2.0):
        """
        tolerance_pct: 5% relative tolerance for CHF amounts
        tolerance_abs: 2 points absolute tolerance for percentages
        Returns list of hallucinated numbers.
        """
```

**prompt_registry.py:**

Contains ALL system prompts, versioned, with full banned terms list embedded.
See MINT_COACH_VIVANT_ROADMAP.md § S34 for the exact base system prompt.

**Tests (test_compliance_guard.py — min 25 ADVERSARIAL tests):**

Test with deliberately non-compliant LLM outputs:
```python
# Must catch banned terms
"C'est le meilleur investissement que tu puisses faire."  # → FAIL: "meilleur"
"Sans aucun risque de marché."  # → FAIL: "sans risque"
"Tu devrais faire un rachat LPP."  # → FAIL: "tu devrais" + prescriptive

# Must catch prescriptive language
"Fais un rachat de 10'000 CHF."  # → FAIL: prescriptive
"Priorité absolue : monter à 6 mois."  # → FAIL: prescriptive
"C'est plus important que ton 3a cette année."  # → FAIL: prescriptive

# Must catch hallucinated numbers
# context: {"score": 62}, LLM says "ton score est à 72" → FAIL: hallucination

# Must pass compliant text
"Dans ce scénario simulé, un versement 3a pourrait réduire ton impôt d'environ CHF 1'820."  # → PASS
"Ta solidité financière est de 62/100, en progression de 4 points."  # → PASS

# Edge cases
""  # → FAIL: empty output
"A" * 5000  # → FAIL: too long
"Your score is 62."  # → FAIL: wrong language (English)
```

**Tests (test_hallucination_detector.py — min 15 tests):**
- Test extraction of CHF amounts in various formats (CHF 1'820, CHF 1820, CHF 1,820.50)
- Test extraction of percentages (4.5%, 27%)
- Test tolerance: CHF 1'820 vs known 1'800 → PASS (within 5%)
- Test tolerance: CHF 2'500 vs known 1'800 → FAIL (outside 5%)
- Test with no numbers in text → PASS (nothing to verify)
- Test with multiple numbers, one hallucinated → FAIL

---

**FLUTTER AGENT SPEC:**

Create:
```
apps/mobile/lib/services/coach/compliance_guard.dart
apps/mobile/lib/services/coach/hallucination_detector.dart
apps/mobile/lib/services/coach/prompt_registry.dart
apps/mobile/lib/services/coach/coach_models.dart
```

Mirror backend logic exactly. Same banned terms. Same patterns. Same tolerances.

---

### ═══════════════════════════════════════
### S35 — COACH NARRATIVE SERVICE
### ═══════════════════════════════════════

**Read first**: MINT_COACH_VIVANT_ROADMAP.md § S35

**PREREQUISITE: S34 (ComplianceGuard) MUST be complete and ALL tests passing.**

**BACKEND AGENT SPEC:**

Create:
```
services/backend/app/services/coach/coach_narrative_service.py
services/backend/app/services/coach/coach_context_builder.py
services/backend/app/services/coach/fallback_templates.py
services/backend/app/api/v1/endpoints/coach.py
services/backend/tests/test_coach_narrative.py
services/backend/tests/test_fallback_templates.py
```

**Architecture: 4 independent LLM calls, NOT 1 monolithic call.**

```python
class CoachNarrativeService:
    async def generate_greeting(self, ctx: CoachContext) -> str:
        """Max 30 words. Independent cache. Independent fallback."""

    async def generate_score_summary(self, ctx: CoachContext) -> str:
        """Max 80 words. Invalidated on check-in."""

    async def generate_tip_narrative(self, ctx: CoachContext, raw_tip: dict) -> str:
        """Max 120 words. Takes raw trigger from CoachingService."""

    async def generate_chiffre_choc_reframe(self, ctx: CoachContext, chiffre: dict) -> str:
        """Max 100 words. Emotional reframe of chiffre choc."""
```

Each method:
1. Builds prompt from PromptRegistry
2. Calls BYOK LLM (if available)
3. Passes output through ComplianceGuard
4. If compliant → cache + return
5. If not compliant → return FallbackTemplates output

**CoachContext — what is sent to LLM:**
```python
@dataclass
class CoachContext:
    first_name: str
    archetype: str
    age: int
    canton: str
    # Financial state (aggregated, never raw)
    fri_total: float
    fri_delta: float
    primary_focus: str
    replacement_ratio: float
    months_liquidity: float
    tax_saving_potential: float       # CHF — only precise number sent
    confidence_score: float
    # Temporal
    today: date
    days_since_last_visit: int
    fiscal_season: str | None         # "3a_deadline", "tax_declaration", None
    # Behavioral
    check_in_streak: int
    last_milestone: str | None
```

**NEVER include in CoachContext:**
- Exact gross salary
- Exact savings balance
- Exact debt amounts
- Bank names, account numbers
- Employer name
- NPA, address
- Family members' names

**fallback_templates.py — Enhanced templates (NOT current static text):**

These use CoachContext for personalization WITHOUT LLM.
They are the minimum quality bar. LLM output must be better.

```python
class FallbackTemplates:
    @staticmethod
    def greeting(ctx: CoachContext) -> str:
        if ctx.days_since_last_visit == 0:
            return f"Bon retour, {ctx.first_name}."
        if ctx.fiscal_season == "3a_deadline":
            days_left = (date(ctx.today.year, 12, 31) - ctx.today).days
            return f"{ctx.first_name}, il reste {days_left} jours pour ton 3a."
        if ctx.fri_delta > 0:
            return f"Salut {ctx.first_name}. +{ctx.fri_delta} points depuis ta dernière visite."
        return f"Salut {ctx.first_name}. Ton score de solidité : {ctx.fri_total}/100."
```

---

**FLUTTER AGENT SPEC:**

Create:
```
apps/mobile/lib/services/coach/coach_narrative_service.dart
apps/mobile/lib/services/coach/coach_context_builder.dart
apps/mobile/lib/services/coach/coach_cache_service.dart
apps/mobile/lib/services/coach/fallback_templates.dart
apps/mobile/lib/screens/dashboard/coach_pulse_card.dart
apps/mobile/lib/screens/dashboard/coach_tip_card.dart
apps/mobile/lib/screens/dashboard/coach_chiffre_choc_card.dart
```

**coach_cache_service.dart — Smart invalidation:**

```dart
enum InvalidationTrigger {
  checkIn,        // invalidates: scoreSummary, tipNarrative
  profileUpdate,  // invalidates: ALL
  newDay,         // invalidates: greeting only
  arbitrage,      // invalidates: chiffreChocReframe
  manualRefresh,  // invalidates: ALL
}
```

Cache stored in SharedPreferences. Key = component + context hash.
On cache miss → call LLM (if BYOK) → ComplianceGuard → cache result.
On cache hit → return cached content immediately.

---

### ═══════════════════════════════════════
### S36 — NOTIFICATIONS + MILESTONES
### ═══════════════════════════════════════

**Read first**: MINT_COACH_VIVANT_ROADMAP.md § S36

**FLUTTER AGENT SPEC (Flutter-heavy sprint):**

Create:
```
apps/mobile/lib/services/notification_scheduler_service.dart
apps/mobile/lib/services/milestone_detection_service.dart
apps/mobile/lib/screens/milestone_celebration_sheet.dart
```

**Notifications — 3 tiers:**

Tier 1 (calendar): Scheduled at app launch using flutter_local_notifications.
Tier 2 (event): Triggered on app resume via WidgetsBindingObserver.
Tier 3 (BYOK): Same triggers, text generated by CoachNarrativeService.

**Every notification MUST contain:**
- A personal number (CHF amount or percentage)
- A time reference (deadline, duration)
- A deeplink to relevant screen

**Every notification MUST NOT contain:**
- Generic encouragement
- Social comparison
- Prescriptive language

**Milestones — celebration bottom sheet:**

Use `confetti` package for animation.
Milestone text: without BYOK → hardcoded factual text.
With BYOK → LLM generates → ComplianceGuard validates.

**COMPLIANCE RULE: No social comparison in milestones.**
BANNED: "Tu es dans le top 20% des Suisses."
ALLOWED: "Plafond 3a atteint. Économie fiscale estimée : ~CHF {saving}."

---

### ═══════════════════════════════════════
### S37 — SCENARIO NARRATION + ANNUAL REFRESH
### ═══════════════════════════════════════

**Read first**: MINT_COACH_VIVANT_ROADMAP.md § S37

**BACKEND + FLUTTER — Scenario Narrator:**

After ForecasterService.project() returns 3 scenarios:
- Without BYOK: structured text with numbers
- With BYOK: LLM narrates each scenario (max 150 words each)
- ComplianceGuard verifies: numbers match (±5%), uncertainty mentioned, no prescriptive language

**FLUTTER — Annual Refresh:**

Trigger: profile.lastMajorUpdate > 11 months.
Flow: 7 questions pre-filled with current values.
After refresh: full recalculation → new snapshot → FRI delta → celebration if improvement.

---

### ═══════════════════════════════════════
### S38 — FRI SHADOW MODE
### ═══════════════════════════════════════

**Read first**: ONBOARDING_ARBITRAGE_ENGINE.md § V (FRI)

**FRI computed but NOT displayed.**

Create:
```
apps/mobile/lib/services/financial_core/fri_calculator.dart
services/backend/app/services/fri/fri_service.py
services/backend/tests/test_fri.py
```

**FRI = L + F + R + S (each 0-25)**

```dart
// L — Liquidity (non-linear: sqrt for diminishing returns)
double L = 25 * min(1.0, sqrt(monthsCover / 6.0));
if (shortTermDebtRatio > 0.30) L -= 4;
if (incomeVolatility == "high") L -= 3;

// F — Fiscal efficiency
double F = 25 * (0.6 * utilisation3a + 0.25 * utilisationRachat + 0.15 * utilisationAmortIndirect);
// IMPORTANT: rachat penalty only if tauxMarginal > 0.25

// R — Retirement (non-linear: pow 1.5)
double R = 25 * min(1.0, pow(replacementRatio / 0.70, 1.5));

// S — Structural risk (penalty-based)
double S = 25;
if (disabilityGapRatio > 0.20) S -= 6;
if (hasDependents && deathProtectionGapRatio > 0.30) S -= 6;
if (mortgageStressRatio > 0.36) S -= 5;
if (concentrationRatio > 0.70) S -= 4;
if (employerDependencyRatio > 0.80) S -= 4;
```

MUST use `financial_core/` calculators for all inputs. NEVER reimplement.
Log FRI in snapshots. Do NOT display to users yet.

---

### ═══════════════════════════════════════
### S39 — FRI BETA + LONGITUDINAL CHARTS
### ═══════════════════════════════════════

**Prerequisite: S38 shadow data validated. No extreme outliers.**

Display FRI to users. Only if `confidenceScore >= 50%`.

Create:
```
apps/mobile/lib/screens/fri/fri_dashboard_card.dart
apps/mobile/lib/screens/fri/fri_history_chart.dart
apps/mobile/lib/widgets/fri/fri_breakdown_bars.dart
```

**Display rules:**
- Always show breakdown (4 bars), never just total
- Always show top improvement action
- Never say "faible", "mauvais", "insuffisant"
- Never compare to other users
- Show progression vs own past (from snapshots)

---

### ═══════════════════════════════════════
### S40 — REENGAGEMENT + CONSENT
### ═══════════════════════════════════════

**Read first**: ONBOARDING_ARBITRAGE_ENGINE.md § VII + MINT_COACH_VIVANT_ROADMAP.md § S40

Create:
```
apps/mobile/lib/services/reengagement_engine.dart
apps/mobile/lib/services/consent_manager.dart
apps/mobile/lib/screens/settings/consent_dashboard_screen.dart
```

**Consent dashboard — 3 independent toggles:**
1. BYOK data sharing (shows exactly which fields sent to which provider)
2. Snapshot storage (longitudinal tracking)
3. Notification opt-in

Each toggle independent. Each revocable immediately.

---

## GLOBAL RULES (apply to ALL sprints)

### Before EVERY sprint:
```bash
# Backend
cd services/backend && python3 -m pytest tests/ -q
# Flutter
cd apps/mobile && flutter analyze && flutter test
```

All must pass. If baseline is broken, fix BEFORE starting sprint.

### During EVERY sprint:

1. **Read existing code before writing.** Always understand what exists.
2. **Import financial_core.dart for ALL calculations.** Never duplicate.
3. **Backend = source of truth.** Flutter must produce identical results.
4. **Every user-facing string in French.** Informal "tu". Inclusive language.
5. **Every service output includes:** disclaimer, sources, confidenceScore.
6. **Every calculator output includes:** chiffre_choc, alertes.
7. **No banned terms.** Run compliance check before committing.
8. **Surgical git commit.** Only sprint-specific files.

### After EVERY sprint:
```bash
# Full test suite
cd services/backend && python3 -m pytest tests/ -q
cd apps/mobile && flutter analyze && flutter test
# Verify zero new errors
```

### Constants (from CLAUDE.md — source of truth):
- 3a plafond salarié: 7'258 CHF
- 3a plafond indépendant: 20% revenu net, max 36'288 CHF
- LPP seuil accès: 22'680 CHF
- LPP coordination: 26'460 CHF
- LPP coordonné min: 3'780 CHF
- LPP conversion: 6.8%
- LPP bonifications: 7% (25-34), 10% (35-44), 15% (45-54), 18% (55-65)
- AVS rente max: 30'240 CHF/an
- Hypothèque taux théorique: 5%
- Hypothèque ratio charges max: 1/3

---

## DEPENDENCY GRAPH (respect this order)

```
S31 (Onboarding) ──→ S32 (Arbitrage P1) ──→ S33 (Arbitrage P2 + Snapshots)
                                                       │
S34 (Compliance Guard) ◄── BLOCKER ──────────────────────┘
  │
  ├──→ S35 (Coach Narrative)
  │      └──→ S36 (Notifications + Milestones)
  │             └──→ S37 (Scenarios + Refresh)
  │
  └──→ S38 (FRI Shadow) ──→ S39 (FRI Beta)
                                    │
                              S40 (Reengagement + Consent) ◄──┘
```

**S34 is the critical path.** Nothing in the Coach Layer ships without it.
**S31-S33 can run in parallel with S34** (no LLM dependency).

---

## SUCCESS CRITERIA

The implementation is complete when:

- [ ] Onboarding produces a chiffre choc in < 60 seconds from 3 inputs
- [ ] All 5 arbitrage modules produce side-by-side comparisons with crossover points
- [ ] Rente vs Capital always shows the mixed (oblig/suroblig) option
- [ ] ComplianceGuard catches 100% of banned terms in adversarial tests
- [ ] HallucinationDetector catches fabricated numbers with < 5% false negatives
- [ ] Coach narrative degrades gracefully without BYOK (enhanced fallback templates)
- [ ] FRI is computed correctly for all 8 archetypes
- [ ] Snapshots are stored with explicit consent only
- [ ] All notifications contain a personal number + time reference
- [ ] Zero banned terms in any user-facing string across the entire app
- [ ] All existing tests still pass (regression = zero)
- [ ] `flutter analyze` = 0 errors

---

*This prompt is the execution contract. If anything is unclear, re-read the source documents.
If anything contradicts CLAUDE.md, CLAUDE.md wins. Always.*
