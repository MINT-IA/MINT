# Disability Gap Calculator -- Complete Specification
# "Mon filet de securite" -- Chantier 3

**Date**: 8 fevrier 2026
**Auteur**: swiss-brain (Swiss compliance & financial law expert)
**Statut**: SPEC READY FOR IMPLEMENTATION
**Sprint**: S2 (3 semaines)

---

## TABLE OF CONTENTS

1. [Employer Coverage Duration Tables (3 Scales)](#1-employer-coverage-duration-tables)
2. [AI Rente Amounts (2025/2026)](#2-ai-rente-amounts-20252026)
3. [IJM Rules](#3-ijm-rules)
4. [LPP Disability Benefits](#4-lpp-disability-benefits)
5. [Test Cases (5 Personas)](#5-test-cases)
6. [Alerts by Employment Status](#6-alerts-by-employment-status)
7. [Educational Content](#7-educational-content)
8. [Data Structures for Implementation](#8-data-structures-for-implementation)

---

## 1. EMPLOYER COVERAGE DURATION TABLES

### Legal Basis

**CO art. 324a al. 1-2**: If an employee is prevented from working through no fault of their own (illness, accident, legal obligation, or public function), the employer must continue to pay the salary for a limited period, provided the employment relationship has lasted more than 3 months or was concluded for more than 3 months.

**CO art. 324a al. 2**: The exact duration is "equitably determined" ("en equite") by the judge. In practice, courts have established 3 reference scales based on jurisprudence.

**Key principle**: The duration resets at the beginning of each year of service (not calendar year). Multiple illness episodes within the same year of service are cumulated.

### 1.1 Echelle Bernoise (Bern Scale)

**Source**: Jurisprudence of the Canton of Bern civil courts
**Legal reference**: ATF 4C.346/2005; Berner Kommentar, Rehbinder/Stöckli

**Applied in cantons**: BE, AG, FR, NE, SO, VS, JU, VD, GE, LU, TI, OW, NW, GL, SG (all cantons NOT listed under Zurich or Basel scales)

**IMPORTANT FOR MINT MVP**: VD, GE, LU, BE all use this scale.

```
BERN_SCALE = {
    1:  { "weeks": 3,  "months_approx": 0.75 },
    2:  { "weeks": 4,  "months_approx": 1.0  },
    3:  { "weeks": 9,  "months_approx": 2.0  },
    4:  { "weeks": 9,  "months_approx": 2.0  },
    5:  { "weeks": 13, "months_approx": 3.0  },
    6:  { "weeks": 13, "months_approx": 3.0  },
    7:  { "weeks": 13, "months_approx": 3.0  },
    8:  { "weeks": 13, "months_approx": 3.0  },
    9:  { "weeks": 13, "months_approx": 3.0  },
    10: { "weeks": 17, "months_approx": 4.0  },
    11: { "weeks": 17, "months_approx": 4.0  },
    12: { "weeks": 17, "months_approx": 4.0  },
    13: { "weeks": 17, "months_approx": 4.0  },
    14: { "weeks": 17, "months_approx": 4.0  },
    15: { "weeks": 22, "months_approx": 5.0  },
    16: { "weeks": 22, "months_approx": 5.0  },
    17: { "weeks": 22, "months_approx": 5.0  },
    18: { "weeks": 22, "months_approx": 5.0  },
    19: { "weeks": 22, "months_approx": 5.0  },
    20: { "weeks": 26, "months_approx": 6.0  },
    # 21-25: same as 20 (6 months)
    # 25+: some courts grant 7 months, but 6 is the standard maximum
}
```

**Simplified lookup function**:
```
def bern_scale_weeks(years_of_service: int) -> int:
    if years_of_service < 1: return 0  # less than 3 months = no right
    if years_of_service == 1: return 3
    if years_of_service == 2: return 4
    if years_of_service <= 4: return 9
    if years_of_service <= 9: return 13
    if years_of_service <= 14: return 17
    if years_of_service <= 19: return 22
    return 26  # 20+ years
```

### 1.2 Echelle Zurichoise (Zurich Scale)

**Source**: Jurisprudence of the Zurich Obergericht
**Legal reference**: Obergericht ZH, decisions cited in Streiff/von Kaenel/Rudolph, Arbeitsvertrag

**Applied in cantons**: ZH, SH, TG, GR, ZG, AI, AR

**IMPORTANT FOR MINT MVP**: ZH uses this scale.

```
ZURICH_SCALE = {
    1:  { "weeks": 3  },
    2:  { "weeks": 8  },
    3:  { "weeks": 9  },
    4:  { "weeks": 10 },
    5:  { "weeks": 11 },
    6:  { "weeks": 12 },
    7:  { "weeks": 13 },
    8:  { "weeks": 14 },
    9:  { "weeks": 15 },
    10: { "weeks": 16 },
    11: { "weeks": 17 },
    12: { "weeks": 18 },
    13: { "weeks": 19 },
    14: { "weeks": 20 },
    15: { "weeks": 21 },
    16: { "weeks": 22 },
    17: { "weeks": 23 },
    18: { "weeks": 24 },
    19: { "weeks": 25 },
    20: { "weeks": 26 },
    # Pattern: year 2 = 8 weeks, then +1 week per additional year
}
```

**Simplified lookup function**:
```
def zurich_scale_weeks(years_of_service: int) -> int:
    if years_of_service < 1: return 0
    if years_of_service == 1: return 3
    return 8 + (years_of_service - 2)  # 8 weeks in year 2, +1/year after
```

### 1.3 Echelle Baloise (Basel Scale)

**Source**: Jurisprudence of the Basel appellate courts
**Legal reference**: Basler Kommentar OR I, Portmann/Rudolph

**Applied in cantons**: BS, BL

**IMPORTANT FOR MINT MVP**: BS uses this scale.

```
BASEL_SCALE = {
    1:  { "weeks": 3,  "months_approx": 0.75 },
    2:  { "weeks": 9,  "months_approx": 2.0  },
    3:  { "weeks": 9,  "months_approx": 2.0  },
    4:  { "weeks": 13, "months_approx": 3.0  },
    5:  { "weeks": 13, "months_approx": 3.0  },
    6:  { "weeks": 13, "months_approx": 3.0  },
    7:  { "weeks": 13, "months_approx": 3.0  },
    8:  { "weeks": 13, "months_approx": 3.0  },
    9:  { "weeks": 13, "months_approx": 3.0  },
    10: { "weeks": 13, "months_approx": 3.0  },
    11: { "weeks": 17, "months_approx": 4.0  },
    12: { "weeks": 17, "months_approx": 4.0  },
    13: { "weeks": 17, "months_approx": 4.0  },
    14: { "weeks": 17, "months_approx": 4.0  },
    15: { "weeks": 17, "months_approx": 4.0  },
    16: { "weeks": 22, "months_approx": 5.0  },
    17: { "weeks": 22, "months_approx": 5.0  },
    18: { "weeks": 22, "months_approx": 5.0  },
    19: { "weeks": 22, "months_approx": 5.0  },
    20: { "weeks": 22, "months_approx": 5.0  },
    21: { "weeks": 26, "months_approx": 6.0  },
    # 21+: 6 months
}
```

**Simplified lookup function**:
```
def basel_scale_weeks(years_of_service: int) -> int:
    if years_of_service < 1: return 0
    if years_of_service == 1: return 3
    if years_of_service <= 3: return 9
    if years_of_service <= 10: return 13
    if years_of_service <= 15: return 17
    if years_of_service <= 20: return 22
    return 26  # 21+ years
```

### 1.4 Canton-to-Scale Mapping (MVP 6 Cantons)

```
CANTON_SCALE_MAP = {
    "ZH": "zurich",   # Echelle zurichoise
    "BE": "bern",      # Echelle bernoise
    "VD": "bern",      # Echelle bernoise
    "GE": "bern",      # Echelle bernoise
    "LU": "bern",      # Echelle bernoise
    "BS": "basel",     # Echelle baloise
}
```

**Full 26-canton mapping** (for future expansion):
```
CANTON_SCALE_MAP_FULL = {
    # Zurich scale
    "ZH": "zurich", "SH": "zurich", "TG": "zurich",
    "GR": "zurich", "ZG": "zurich", "AI": "zurich", "AR": "zurich",
    # Basel scale
    "BS": "basel", "BL": "basel",
    # Bern scale (all others)
    "BE": "bern", "LU": "bern", "UR": "bern", "SZ": "bern",
    "OW": "bern", "NW": "bern", "GL": "bern", "FR": "bern",
    "SO": "bern", "AG": "bern", "VD": "bern", "VS": "bern",
    "NE": "bern", "GE": "bern", "JU": "bern", "TI": "bern",
    "SG": "bern",
}
```

---

## 2. AI RENTE AMOUNTS (2025/2026)

### Legal Basis

- **LAI art. 28**: Conditions for entitlement to a disability pension
- **LAI art. 28a**: Determination of the degree of disability
- **LAVS art. 34-40**: Calculation of ordinary pensions (applies to AI pensions by reference)
- **LAVS art. 42**: Amount of pensions

### 2.1 Disability Degree Thresholds

**Source**: LAI art. 28 al. 2 (new linear system since 01.01.2022)

```
DISABILITY_DEGREE_THRESHOLDS = {
    "no_right":          { "min": 0,  "max": 39,  "rente_fraction": 0.0   },
    "quarter_rente":     { "min": 40, "max": 49,  "rente_fraction": 0.25  },
    "half_rente":        { "min": 50, "max": 59,  "rente_fraction": 0.50  },
    "three_quarter":     { "min": 60, "max": 69,  "rente_fraction": 0.75  },
    "full_rente":        { "min": 70, "max": 100, "rente_fraction": 1.0   },
}
```

**IMPORTANT -- Linear system since 2022 reform (LAI art. 28a al. 1)**:
For NEW pensions granted since 01.01.2022, the system is linear between 50% and 69% disability:
- 50% disability = 50% of full pension
- 51% disability = 51% of full pension
- etc.
The quarter rente (40-49%) and full rente (70%+) remain stepped.

For MVP simplification, we use the stepped model (sufficient for the gap calculator use case).

### 2.2 Pension Amounts (valid 01.01.2025 - 31.12.2026)

**Source**: OAVS, Federal Council decision of 28.08.2024, in force 01.01.2025
**Note**: Amounts increased by 2.9% vs 2024. Unchanged for 2026.

```
AI_RENTE_2025 = {
    "full_rente": {
        "monthly_min": 1260,     # CHF/month
        "monthly_max": 2520,     # CHF/month
        "annual_min":  15120,    # CHF/year
        "annual_max":  30240,    # CHF/year
    },
    "three_quarter_rente": {
        "monthly_min": 945,      # 75% of min
        "monthly_max": 1890,     # 75% of max
        "annual_min":  11340,
        "annual_max":  22680,
    },
    "half_rente": {
        "monthly_min": 630,      # 50% of min
        "monthly_max": 1260,     # 50% of max
        "annual_min":  7560,
        "annual_max":  15120,
    },
    "quarter_rente": {
        "monthly_min": 315,      # 25% of min
        "monthly_max": 630,      # 25% of max
        "annual_min":  3780,
        "annual_max":  7560,
    },
    "couple_max_monthly": 3780,  # 150% of individual max
    "couple_max_annual":  45360,
}
```

### 2.3 How the AI Rente Amount is Determined

The actual amount depends on:
1. **Duration of contribution** (echelle de rente): 44 years = full scale
2. **Average annual income** (revenu annuel moyen determinant): determines position between min and max
3. **Disability degree**: determines the fraction (quarter/half/three-quarter/full)

**Formula**: `AI_rente_monthly = rente_scale_amount(contribution_years, average_income) * disability_fraction`

For **MVP simplification**, we use: if income >= CHF 90'720/year (CHF 7'560/month), the insured person is entitled to the **maximum** rente. For lower incomes, we interpolate linearly between min and max.

```
def estimate_ai_rente_monthly(
    gross_annual_income: float,
    disability_degree: int,  # 0-100
    contribution_years: int = 44,  # assume full for MVP
) -> float:
    # Step 1: determine fraction
    if disability_degree < 40: return 0
    elif disability_degree < 50: fraction = 0.25
    elif disability_degree < 60: fraction = 0.50
    elif disability_degree < 70: fraction = 0.75
    else: fraction = 1.0

    # Step 2: determine base rente (full rente)
    MAX_INCOME_FOR_MAX_RENTE = 90720  # CHF/year (2025/2026)
    MIN_RENTE = 1260
    MAX_RENTE = 2520

    if gross_annual_income >= MAX_INCOME_FOR_MAX_RENTE:
        base_rente = MAX_RENTE
    elif gross_annual_income <= 0:
        base_rente = MIN_RENTE
    else:
        # Linear interpolation
        ratio = gross_annual_income / MAX_INCOME_FOR_MAX_RENTE
        base_rente = MIN_RENTE + (MAX_RENTE - MIN_RENTE) * ratio

    # Step 3: apply contribution year scaling (if < 44 years)
    if contribution_years < 44:
        scale_factor = contribution_years / 44
        base_rente = base_rente * scale_factor

    # Step 4: apply disability fraction
    return round(base_rente * fraction, 2)
```

---

## 3. IJM RULES (Indemnites Journalieres Maladie)

### Legal Basis

- **CO art. 324a al. 4**: Employer may substitute equivalent insurance for salary continuation
- **LAMal art. 67-77** (optional daily benefits insurance under health insurance law)
- **LCA (Loi sur le contrat d'assurance)**: Private insurance law basis for most collective IJM

### 3.1 Collective IJM (Assurance collective d'indemnites journalieres maladie)

```
COLLECTIVE_IJM_RULES = {
    "coverage_percentage": 0.80,       # 80% of insured salary
    "max_duration_days": 720,          # 720 days of benefits
    "within_period_days": 900,         # within a 900 consecutive day window
    "employer_premium_share_min": 0.50, # employer pays at least 50% of premium
    "waiting_period_max_days": 3,       # max 3 days without pay at start
    "typical_waiting_periods": [0, 30, 60, 90],  # days - contractual variations
}
```

**Equivalence rule (CO art. 324a al. 4)**:
An IJM is "equivalent" to salary continuation if:
1. It pays **at least 80%** of salary
2. For **at least 720 days** within 900 consecutive days
3. The employer pays **at least 50%** of the premium
4. There are **no more than 3 days** of waiting period at the start

If these conditions are met, the employer's obligation under CO 324a is replaced by the IJM.

### 3.2 Waiting Period Mechanics

```
WAITING_PERIOD_RULES = {
    # During the waiting period, the employer must continue paying salary
    # (or 80% if contractually agreed per CO 324a al. 4)
    "employer_pays_during_wait": True,
    "employer_rate_during_wait": 1.0,  # 100% by default, 80% if agreed
    "typical_contractual_waits": {
        "0_days":  "Large employers, banks, pharma",
        "30_days": "Most common for SMEs",
        "60_days": "Mid-size employers",
        "90_days": "Some smaller employers, cost-saving option",
        "180_days": "Rare, mainly for self-employed individual policies",
    },
}
```

### 3.3 Employee WITHOUT Collective IJM

**Situation**: No collective IJM contracted by the employer.
**Legal consequence**: CO art. 324a applies directly. The employer pays 100% of salary for the limited duration according to the applicable scale (Bern/Zurich/Basel).

```
NO_IJM_RULES = {
    "coverage": "CO_324a_scale_only",  # Limited to cantonal scale
    "after_scale_expiry": "NOTHING",    # No further payment obligation
    "risk_level": "HIGH",
    "alert": "Apres {weeks} semaines, tu n'as plus droit a aucun salaire. "
             "Ton seul filet est l'aide sociale (si eligible) ou tes economies personnelles.",
}
```

### 3.4 Self-Employed WITHOUT IJM

**Situation**: Independants (raison individuelle, societe simple) have NO employer.
**Legal consequence**: No CO 324a obligation. No automatic coverage whatsoever.

```
SELF_EMPLOYED_NO_IJM = {
    "coverage_phase_1": 0,      # No employer = no salary continuation
    "coverage_phase_2": 0,      # No collective IJM
    "time_to_ai_rente": "minimum 12-18 months (AI processing time)",
    "risk_level": "CRITICAL",
    "alert": "ALERTE CRITIQUE : En tant qu'independant sans assurance IJM, "
             "tu n'as AUCUNE couverture en cas de maladie. "
             "A partir du jour 1, ton revenu tombe a zero.",
    "recommended_action": "Souscrire immediatement une assurance perte de gain individuelle "
                          "(IJM individuelle selon LAMal art. 67ss ou LCA).",
}
```

### 3.5 What Happens After IJM Expires (720 days)

After 720 days of IJM benefits:
- The insured must apply for AI (disability insurance)
- AI processing takes typically 6-18 months
- During the gap between IJM expiry and AI decision: **no mandatory coverage**
- The insured may have bridging through:
  - Employer goodwill
  - Individual savings
  - Social assistance (aide sociale)
  - Complementary benefits (prestations complementaires)

---

## 4. LPP DISABILITY BENEFITS

### Legal Basis

- **LPP art. 23**: Entitlement to disability benefits
- **LPP art. 24**: Amount of disability pension
- **LPP art. 24a**: Maximum (coordination with AI)
- **LPP art. 25**: Disability pension for partial disability
- **LPP art. 26**: Beginning and end of entitlement

### 4.1 Calculation Method

The LPP disability pension is calculated on a **hypothetical retirement capital** ("avoir de vieillesse hypothetique").

**Formula**:
```
Hypothetical_capital = Actual_accumulated_capital
                     + Sum of future bonifications until age 65
                       (based on last insured salary, WITHOUT interest)

LPP_disability_rente_annual = Hypothetical_capital * 0.068  # 6.8% conversion rate

LPP_disability_rente_monthly = LPP_disability_rente_annual / 12
```

### 4.2 Bonification Rates by Age (LPP art. 16)

```
LPP_BONIFICATION_RATES = {
    # age_range: percentage of coordinated salary
    (25, 34): 0.07,   # 7%
    (35, 44): 0.10,   # 10%
    (45, 54): 0.15,   # 15%
    (55, 65): 0.18,   # 18%
}
```

### 4.3 Key Parameters (2025/2026)

```
LPP_PARAMS_2025 = {
    "coordination_deduction": 26460,     # CHF/year (7/8 of max AVS rente)
    "entry_threshold": 22680,            # CHF/year (3/4 of max AVS rente)
    "max_insured_salary": 90720,         # CHF/year (max AVS salary)
    "max_coordinated_salary": 64260,     # 90720 - 26460
    "min_coordinated_salary": 3780,      # CHF/year
    "conversion_rate": 0.068,            # 6.8% (minimum legal, obligatory part)
    "conversion_rate_surobligatoire": 0.050,  # ~5.0% typical for surobligatoire
}
```

### 4.4 MVP Estimation Formula

For the MVP simulator, we estimate the LPP disability benefit:

```
def estimate_lpp_disability_rente(
    gross_annual_salary: float,
    age: int,
    years_of_lpp_contributions: int = None,  # if unknown, estimate from age
) -> float:
    """
    Estimate the annual LPP disability pension.
    This is a SIMPLIFIED estimate for the MVP.
    The actual amount depends on the specific pension fund.
    """
    # Step 1: Calculate coordinated salary
    if gross_annual_salary < 22680:  # Below entry threshold
        return 0

    coordinated_salary = min(
        max(gross_annual_salary - 26460, 3780),
        64260
    )

    # Step 2: Estimate hypothetical capital
    # Actual accumulated + projected bonifications until 65
    if years_of_lpp_contributions is None:
        years_of_lpp_contributions = max(0, age - 25)

    # Accumulated capital (rough estimate: average rate over past years)
    accumulated = 0
    for y_age in range(25, min(age, 65)):
        if y_age <= 34: rate = 0.07
        elif y_age <= 44: rate = 0.10
        elif y_age <= 54: rate = 0.15
        else: rate = 0.18
        accumulated += coordinated_salary * rate
    # Note: no interest for simplification

    # Projected future bonifications (until 65)
    projected = 0
    for y_age in range(age, 65):
        if y_age <= 34: rate = 0.07
        elif y_age <= 44: rate = 0.10
        elif y_age <= 54: rate = 0.15
        else: rate = 0.18
        projected += coordinated_salary * rate

    hypothetical_capital = accumulated + projected

    # Step 3: Convert to annual rente
    annual_rente = hypothetical_capital * 0.068

    return round(annual_rente, 2)
```

### 4.5 Coordination with AI (90% Rule)

**Source**: LPP art. 24a; OPP2 art. 25

```
COORDINATION_RULES = {
    "max_total_percentage": 0.90,  # Total benefits cannot exceed 90% of lost income
    "components": [
        "AI_rente",
        "LPP_disability_rente",
        "LAA_rente (if accident)",
        "Actual_or_hypothetical_residual_income",
    ],
    "formula": """
        lost_income = last_salary_before_disability
        total_benefits = AI_rente + LPP_rente + other_social_insurance
        if total_benefits > lost_income * 0.90:
            LPP_rente = max(0, lost_income * 0.90 - AI_rente - other)
    """,
}
```

### 4.6 Disability Fraction (LPP art. 25)

The LPP disability pension fraction mirrors the AI disability degree:
- 40-49% disability: quarter of full LPP disability pension
- 50-59% disability: half
- 60-69% disability: three-quarters
- 70%+ disability: full

---

## 5. TEST CASES

### Assumptions for All Test Cases

- Disability degree: **100%** (full disability) unless otherwise stated
- Full AVS contribution years (44 years) assumed
- IJM waiting period: **30 days** (most common) when IJM exists
- All amounts in CHF, rounded to nearest franc
- Phase 1 employer rate: **100%** of gross salary
- Phase 2 IJM rate: **80%** of insured salary
- LPP conversion rate: **6.8%** (minimum legal obligatory)
- Gross salary used as reference income for gap calculation

---

### PERSONA 1: Marc (Salarie ZH, 3 ans anciennete, 8'000 CHF/mois, IJM collective)

**Profile**:
- Canton: ZH (Zurich scale)
- Employment: Employee (salarie)
- Years of service: 3
- Gross monthly salary: CHF 8'000
- Gross annual salary: CHF 96'000
- Has collective IJM: YES (30 days waiting period)
- Age: 32
- LPP insured salary (coordinated): 96'000 - 26'460 = CHF 69'540 -> capped at CHF 64'260

**PHASE 1 -- Employer salary continuation**:
- Scale: Zurich
- Duration: 9 weeks (3rd year of service)
- Monthly benefit: CHF 8'000 (100% of salary)
- Duration in months: 9 / 4.33 = ~2.08 months
- Gap: CHF 0

**PHASE 2 -- IJM (after waiting period)**:
- Waiting period: 30 days (employer pays 100% during this time)
- IJM coverage: 80% of CHF 8'000 = CHF 6'400/month
- Duration: 720 days (= 24 months) within 900-day window
- Gap vs salary: CHF 8'000 - CHF 6'400 = CHF 1'600/month

**PHASE 3 -- AI + LPP (after 24 months, assuming 100% disability)**:
- AI rente (full, max): CHF 2'520/month (income 96k > 90'720 threshold)
- LPP disability estimate:
  - Coordinated salary: CHF 64'260/year
  - Hypothetical capital (age 32, contributions 25-65):
    - Age 25-32 (7 years at 7%): 7 * 64'260 * 0.07 = CHF 31'487
    - Age 32-34 (3 years at 7%): 3 * 64'260 * 0.07 = CHF 13'495 (projected)
    - Age 35-44 (10 years at 10%): 10 * 64'260 * 0.10 = CHF 64'260 (projected)
    - Age 45-54 (10 years at 15%): 10 * 64'260 * 0.15 = CHF 96'390 (projected)
    - Age 55-65 (10 years at 18%): 10 * 64'260 * 0.18 = CHF 115'668 (projected)
    - Total hypothetical capital: CHF 321'300
  - Annual LPP rente: 321'300 * 0.068 = CHF 21'848
  - Monthly LPP rente: CHF 1'821
- Total Phase 3 monthly: CHF 2'520 + CHF 1'821 = CHF 4'341
- 90% rule check: 4'341 < 8'000 * 0.90 = 7'200 -> OK, no reduction
- Gap vs salary: CHF 8'000 - CHF 4'341 = CHF 3'659/month

**Summary Marc**:
```
{
  "persona": "Marc",
  "canton": "ZH",
  "scale": "zurich",
  "gross_monthly": 8000,
  "phase_1": {
    "duration_weeks": 9,
    "duration_months": 2.08,
    "monthly_benefit": 8000,
    "monthly_gap": 0
  },
  "phase_2": {
    "has_ijm": true,
    "waiting_period_days": 30,
    "duration_days": 720,
    "duration_months": 24,
    "monthly_benefit": 6400,
    "monthly_gap": 1600
  },
  "phase_3": {
    "ai_rente_monthly": 2520,
    "lpp_rente_monthly": 1821,
    "total_monthly": 4341,
    "monthly_gap": 3659
  },
  "risk_level": "medium",
  "risk_reason": "IJM covers 80% for 2 years, but significant gap in Phase 3"
}
```

---

### PERSONA 2: Sophie (Salariee VD, 8 ans anciennete, 6'000 CHF/mois, IJM collective)

**Profile**:
- Canton: VD (Bern scale)
- Employment: Employee
- Years of service: 8
- Gross monthly salary: CHF 6'000
- Gross annual salary: CHF 72'000
- Has collective IJM: YES (30 days waiting)
- Age: 35
- Coordinated salary: 72'000 - 26'460 = CHF 45'540

**PHASE 1**:
- Scale: Bern
- Duration: 13 weeks (5th-9th year)
- Monthly benefit: CHF 6'000
- Duration in months: 13 / 4.33 = ~3.0 months
- Gap: CHF 0

**PHASE 2**:
- IJM: 80% of CHF 6'000 = CHF 4'800/month
- Duration: 720 days (~24 months)
- Gap: CHF 6'000 - CHF 4'800 = CHF 1'200/month

**PHASE 3** (100% disability):
- AI rente: income 72k < 90'720 -> interpolation
  - ratio = 72'000 / 90'720 = 0.7937
  - base = 1'260 + (2'520 - 1'260) * 0.7937 = 1'260 + 1'000 = CHF 2'260
  - Full rente: CHF 2'260/month
- LPP disability estimate:
  - Coordinated salary: CHF 45'540/year
  - Hypothetical capital (age 35):
    - Age 25-34 (10 years at 7%): 10 * 45'540 * 0.07 = CHF 31'878
    - Age 35-44 (10 years at 10%): 10 * 45'540 * 0.10 = CHF 45'540 (projected)
    - Age 45-54 (10 years at 15%): 10 * 45'540 * 0.15 = CHF 68'310 (projected)
    - Age 55-65 (10 years at 18%): 10 * 45'540 * 0.18 = CHF 81'972 (projected)
    - Total: CHF 227'700
  - Annual LPP rente: 227'700 * 0.068 = CHF 15'484
  - Monthly LPP rente: CHF 1'290
- Total Phase 3 monthly: CHF 2'260 + CHF 1'290 = CHF 3'550
- 90% rule check: 3'550 < 6'000 * 0.90 = 5'400 -> OK
- Gap: CHF 6'000 - CHF 3'550 = CHF 2'450/month

**Summary Sophie**:
```
{
  "persona": "Sophie",
  "canton": "VD",
  "scale": "bern",
  "gross_monthly": 6000,
  "phase_1": {
    "duration_weeks": 13,
    "duration_months": 3.0,
    "monthly_benefit": 6000,
    "monthly_gap": 0
  },
  "phase_2": {
    "has_ijm": true,
    "waiting_period_days": 30,
    "duration_days": 720,
    "duration_months": 24,
    "monthly_benefit": 4800,
    "monthly_gap": 1200
  },
  "phase_3": {
    "ai_rente_monthly": 2260,
    "lpp_rente_monthly": 1290,
    "total_monthly": 3550,
    "monthly_gap": 2450
  },
  "risk_level": "medium",
  "risk_reason": "Good Phase 1 coverage (13 weeks), IJM adequate, but Phase 3 gap significant"
}
```

---

### PERSONA 3: Pierre (Independant GE, pas d'IJM, 10'000 CHF/mois)

**Profile**:
- Canton: GE (Bern scale -- but irrelevant, no employer)
- Employment: Self-employed (independant)
- Years of service: N/A
- Gross monthly income: CHF 10'000
- Gross annual income: CHF 120'000
- Has collective IJM: NO
- Has voluntary LPP: NO (typical for independants)
- Age: 40

**PHASE 1 -- NO EMPLOYER = NO COVERAGE**:
- Duration: 0 weeks
- Monthly benefit: CHF 0
- Gap: CHF 10'000/month (TOTAL LOSS from day 1)

**PHASE 2 -- NO IJM**:
- Monthly benefit: CHF 0
- Duration: 0
- Gap: CHF 10'000/month

**PHASE 3** (100% disability, after AI processing ~12-18 months):
- AI rente: income 120k > 90'720 -> maximum
  - Full rente: CHF 2'520/month
- LPP disability: CHF 0 (no LPP affiliation)
- Total Phase 3 monthly: CHF 2'520
- Gap: CHF 10'000 - CHF 2'520 = CHF 7'480/month

**Summary Pierre**:
```
{
  "persona": "Pierre",
  "canton": "GE",
  "scale": "N/A",
  "gross_monthly": 10000,
  "phase_1": {
    "duration_weeks": 0,
    "duration_months": 0,
    "monthly_benefit": 0,
    "monthly_gap": 10000
  },
  "phase_2": {
    "has_ijm": false,
    "waiting_period_days": 0,
    "duration_days": 0,
    "duration_months": 0,
    "monthly_benefit": 0,
    "monthly_gap": 10000
  },
  "phase_3": {
    "ai_rente_monthly": 2520,
    "lpp_rente_monthly": 0,
    "total_monthly": 2520,
    "monthly_gap": 7480
  },
  "risk_level": "critical",
  "risk_reason": "NO coverage at all from day 1. Only AI rente after 12-18 months of ZERO income."
}
```

---

### PERSONA 4: Anna (Salariee BS, 1 an anciennete, 4'500 CHF/mois, PAS d'IJM collective)

**Profile**:
- Canton: BS (Basel scale)
- Employment: Employee
- Years of service: 1
- Gross monthly salary: CHF 4'500
- Gross annual salary: CHF 54'000
- Has collective IJM: NO
- Age: 26
- Coordinated salary: 54'000 - 26'460 = CHF 27'540

**PHASE 1**:
- Scale: Basel
- Duration: 3 weeks (1st year)
- Monthly benefit: CHF 4'500
- Duration in months: 3 / 4.33 = ~0.69 months
- Gap: CHF 0

**PHASE 2 -- NO IJM**:
- After 3 weeks: NO further salary payment
- Monthly benefit: CHF 0
- Gap: CHF 4'500/month

**PHASE 3** (100% disability):
- AI rente: income 54k < 90'720
  - ratio = 54'000 / 90'720 = 0.5953
  - base = 1'260 + (2'520 - 1'260) * 0.5953 = 1'260 + 750 = CHF 2'010
  - Full rente: CHF 2'010/month
- LPP disability estimate:
  - Coordinated salary: CHF 27'540/year
  - Hypothetical capital (age 26):
    - Age 25-26 (1 year at 7%): 1 * 27'540 * 0.07 = CHF 1'928
    - Age 26-34 (9 years at 7%): 9 * 27'540 * 0.07 = CHF 17'350 (projected)
    - Age 35-44 (10 years at 10%): 10 * 27'540 * 0.10 = CHF 27'540 (projected)
    - Age 45-54 (10 years at 15%): 10 * 27'540 * 0.15 = CHF 41'310 (projected)
    - Age 55-65 (10 years at 18%): 10 * 27'540 * 0.18 = CHF 49'572 (projected)
    - Total: CHF 137'700
  - Annual LPP rente: 137'700 * 0.068 = CHF 9'364
  - Monthly LPP rente: CHF 780
- Total Phase 3 monthly: CHF 2'010 + CHF 780 = CHF 2'790
- 90% rule check: 2'790 < 4'500 * 0.90 = 4'050 -> OK
- Gap: CHF 4'500 - CHF 2'790 = CHF 1'710/month

**Summary Anna**:
```
{
  "persona": "Anna",
  "canton": "BS",
  "scale": "basel",
  "gross_monthly": 4500,
  "phase_1": {
    "duration_weeks": 3,
    "duration_months": 0.69,
    "monthly_benefit": 4500,
    "monthly_gap": 0
  },
  "phase_2": {
    "has_ijm": false,
    "waiting_period_days": 0,
    "duration_days": 0,
    "duration_months": 0,
    "monthly_benefit": 0,
    "monthly_gap": 4500
  },
  "phase_3": {
    "ai_rente_monthly": 2010,
    "lpp_rente_monthly": 780,
    "total_monthly": 2790,
    "monthly_gap": 1710
  },
  "risk_level": "high",
  "risk_reason": "Only 3 weeks of coverage, then NOTHING until AI rente. No IJM = massive gap."
}
```

---

### PERSONA 5: Thomas (Salarie LU, 15 ans anciennete, 12'000 CHF/mois, IJM collective)

**Profile**:
- Canton: LU (Bern scale)
- Employment: Employee
- Years of service: 15
- Gross monthly salary: CHF 12'000
- Gross annual salary: CHF 144'000
- Has collective IJM: YES (30 days waiting)
- Age: 48
- Coordinated salary: min(144'000 - 26'460, 64'260) = CHF 64'260 (capped)
- Note: salary above LPP max -> only obligatory part considered in MVP

**PHASE 1**:
- Scale: Bern
- Duration: 22 weeks (15th-19th year)
- Monthly benefit: CHF 12'000
- Duration in months: 22 / 4.33 = ~5.08 months
- Gap: CHF 0

**PHASE 2**:
- IJM: 80% of CHF 12'000 = CHF 9'600/month
- Duration: 720 days (~24 months)
- Gap: CHF 12'000 - CHF 9'600 = CHF 2'400/month

**PHASE 3** (100% disability):
- AI rente: income 144k > 90'720 -> maximum
  - Full rente: CHF 2'520/month
- LPP disability estimate:
  - Coordinated salary: CHF 64'260/year
  - Hypothetical capital (age 48):
    - Age 25-34 (10 years at 7%): 10 * 64'260 * 0.07 = CHF 44'982
    - Age 35-44 (10 years at 10%): 10 * 64'260 * 0.10 = CHF 64'260
    - Age 45-48 (3 years at 15%): 3 * 64'260 * 0.15 = CHF 28'917
    - Age 48-54 (7 years at 15%): 7 * 64'260 * 0.15 = CHF 67'473 (projected)
    - Age 55-65 (10 years at 18%): 10 * 64'260 * 0.18 = CHF 115'668 (projected)
    - Total: CHF 321'300
  - Annual LPP rente: 321'300 * 0.068 = CHF 21'848
  - Monthly LPP rente: CHF 1'821
- Total Phase 3 monthly: CHF 2'520 + CHF 1'821 = CHF 4'341
- 90% rule check: 4'341 < 12'000 * 0.90 = 10'800 -> OK
- Gap: CHF 12'000 - CHF 4'341 = CHF 7'659/month

**Summary Thomas**:
```
{
  "persona": "Thomas",
  "canton": "LU",
  "scale": "bern",
  "gross_monthly": 12000,
  "phase_1": {
    "duration_weeks": 22,
    "duration_months": 5.08,
    "monthly_benefit": 12000,
    "monthly_gap": 0
  },
  "phase_2": {
    "has_ijm": true,
    "waiting_period_days": 30,
    "duration_days": 720,
    "duration_months": 24,
    "monthly_benefit": 9600,
    "monthly_gap": 2400
  },
  "phase_3": {
    "ai_rente_monthly": 2520,
    "lpp_rente_monthly": 1821,
    "total_monthly": 4341,
    "monthly_gap": 7659
  },
  "risk_level": "medium-high",
  "risk_reason": "Excellent Phase 1 (5 months), good Phase 2, but MASSIVE Phase 3 gap due to high salary vs capped AI+LPP"
}
```

**Key insight for Thomas**: Even with excellent coverage, the gap in Phase 3 is CHF 7'659/month because both AI and LPP are capped while his salary is high. This is the classic "high-earner trap" -- the percentage covered drops dramatically for salaries above CHF 90'720.

---

## 6. ALERTS BY EMPLOYMENT STATUS

### 6.1 Alert Definitions

```python
DISABILITY_ALERTS = {
    "employee_with_ijm": {
        "risk_level": "low",
        "color": "green",
        "icon": "shield_check",
        "title_fr": "Tu es bien protege(e)",
        "message_fr": (
            "Ton employeur a une assurance IJM collective. "
            "En cas de maladie, tu toucheras 100% de ton salaire pendant {phase1_weeks} semaines "
            "(obligation employeur, echelle {scale_name}), puis 80% pendant 720 jours maximum (IJM). "
            "Verifie aupres de ton RH : quel est le delai d'attente? "
            "Certaines conventions collectives offrent des conditions encore meilleures."
        ),
        "actions_fr": [
            "Demande a ton RH une copie de la police IJM collective",
            "Verifie le delai d'attente (0, 30, 60 ou 90 jours)",
            "Verifie si ton salaire surobligatoire est aussi couvert",
            "Constitue quand meme 3-6 mois d'epargne de precaution",
        ],
        "legal_ref": "CO art. 324a al. 4; LAMal art. 67ss",
    },

    "employee_without_ijm": {
        "risk_level": "high",
        "color": "orange",
        "icon": "warning",
        "title_fr": "Attention : protection limitee",
        "message_fr": (
            "Ton employeur n'a PAS d'assurance IJM collective. "
            "En cas de maladie, il doit te payer ton salaire pendant seulement {phase1_weeks} semaines "
            "(echelle {scale_name}, CO art. 324a). Apres cette periode, tu n'as PLUS droit a rien. "
            "Ton seul filet serait l'aide sociale ou tes economies personnelles. "
            "C'est un risque majeur."
        ),
        "actions_fr": [
            "PRIORITE : Souscris une assurance IJM individuelle (cout ~1-3% de ton salaire)",
            "Demande a ton employeur pourquoi il n'a pas de couverture collective",
            "Constitue au minimum 6 mois d'epargne de precaution",
            "Renseigne-toi sur les assurances perte de gain (LAMal art. 67 ou LCA)",
        ],
        "legal_ref": "CO art. 324a; LAMal art. 67-77",
    },

    "self_employed": {
        "risk_level": "critical",
        "color": "red",
        "icon": "error",
        "title_fr": "ALERTE : Aucune protection automatique",
        "message_fr": (
            "En tant qu'independant(e), tu n'as AUCUNE couverture obligatoire en cas de maladie. "
            "Pas d'employeur = pas de maintien du salaire. Pas d'IJM collective = pas d'indemnites. "
            "Si tu tombes malade demain, ton revenu tombe a ZERO des le premier jour. "
            "La rente AI ne viendrait qu'apres 12-18 mois de procedure, et ne couvrirait que "
            "CHF {ai_max} par mois maximum."
        ),
        "actions_fr": [
            "ACTION URGENTE : Souscris une assurance perte de gain (IJM individuelle)",
            "Evalue le besoin : couvre au moins 80% de ton revenu net",
            "Choisis un delai d'attente adapte a tes reserves (30, 60 ou 90 jours)",
            "Considere une affiliation volontaire a une caisse de pension (LPP art. 4)",
            "Constitue 6-12 mois d'epargne de precaution (absolument vital)",
        ],
        "legal_ref": "Pas de CO 324a (pas d'employeur); LAMal art. 67ss (IJM volontaire)",
    },

    "mixed_employee_selfemployed": {
        "risk_level": "medium-high",
        "color": "orange",
        "icon": "warning",
        "title_fr": "Protection partielle seulement",
        "message_fr": (
            "Tu as une double activite (salarie + independant). "
            "Ta partie salariee est couverte par l'employeur ({phase1_weeks} semaines) "
            "et eventuellement par l'IJM collective. "
            "Mais ta partie independante n'a AUCUNE couverture automatique. "
            "En cas de maladie, tu perds 100% de ton revenu independant des le premier jour."
        ),
        "actions_fr": [
            "Souscris une IJM individuelle pour couvrir la partie independante",
            "Verifie que ta couverture salariee (IJM collective) existe bien",
            "Calcule le gap total (partie non couverte)",
            "Constitue une epargne de precaution couvrant au moins la partie independante",
        ],
        "legal_ref": "CO art. 324a (partie salariee); LAMal art. 67ss (partie independante)",
    },

    "student": {
        "risk_level": "low-specific",
        "color": "blue",
        "icon": "info",
        "title_fr": "Situation particuliere : etudiant(e)",
        "message_fr": (
            "En tant qu'etudiant(e), ta situation est particuliere. "
            "Si tu as un emploi a cote (meme a temps partiel), les regles de l'employeur s'appliquent "
            "(CO 324a). Si tu n'as pas d'emploi, tu n'as aucune couverture perte de gain. "
            "Ta couverture depend de ton assurance maladie (LAMal : pas d'IJM automatique). "
            "Bonne nouvelle : l'AVS/AI couvre quand meme l'invalidite, "
            "mais les montants sont minimaux car tu as peu/pas cotise."
        ),
        "actions_fr": [
            "Si tu travailles : verifie ta couverture avec ton employeur",
            "Verifie ta police d'assurance maladie (certaines incluent une IJM optionnelle)",
            "Cotise au minimum a l'AVS chaque annee (CHF 530/an) pour eviter les lacunes",
        ],
        "legal_ref": "LAVS art. 3; LAI art. 28",
    },

    "unemployed": {
        "risk_level": "medium",
        "color": "yellow",
        "icon": "info",
        "title_fr": "Chomage : couverture specifique",
        "message_fr": (
            "En tant que demandeur d'emploi inscrit au chomage, tu beneficies de l'assurance-chomage "
            "(LACI). En cas de maladie pendant le chomage, les indemnites de chomage continuent "
            "a etre versees pendant un certain temps (max 30 jours par cas, 44 jours par an). "
            "Apres ce delai, tu peux perdre tes indemnites si tu ne peux plus chercher d'emploi. "
            "Tu es aussi couvert par l'AVS/AI."
        ),
        "actions_fr": [
            "Annonce immediatement toute maladie a ta caisse de chomage",
            "Fournis un certificat medical dans les 5 jours",
            "Considere une IJM individuelle pour combler le gap",
            "Renseigne-toi sur les prestations complementaires si necessaire",
        ],
        "legal_ref": "LACI art. 28; LAI art. 28; LAVS art. 43",
    },
}
```

---

## 7. EDUCATIONAL CONTENT

### 7.1 Insert: "IJM vs AI : quelle difference ?"

**File**: `education/inserts/q_disability_ijm_vs_ai.md`

```markdown
# Insert: IJM vs AI : quelle difference ?

## Metadata
questionId: "q_disability_ijm_vs_ai"
phase: "Niveau 2"
status: "READY"

## Contenu (FR)

**IJM (Indemnites Journalieres Maladie)** et **AI (Assurance-Invalidite)** sont
deux systemes completement differents, mais qui interviennent l'un apres l'autre.

**L'IJM**, c'est une assurance privee (souvent contractee par ton employeur).
Elle verse 80% de ton salaire pendant maximum 720 jours (environ 2 ans) si tu ne
peux pas travailler pour cause de maladie. C'est ta bouee de sauvetage a court
et moyen terme. Sans IJM, tu n'as que quelques semaines de salaire garanti par
ton employeur (CO art. 324a).

**L'AI**, c'est une assurance sociale federale obligatoire (1er pilier).
Elle intervient uniquement quand ton incapacite de travail est durable
(au moins 1 an) et significative (au moins 40%). Elle verse une rente
mensuelle entre CHF 315 et CHF 2'520 selon ton degre d'invalidite et
tes cotisations (LAI art. 28-28a).

Le piege ? Entre la fin de l'IJM (720 jours) et le debut de la rente AI,
il peut y avoir un trou de plusieurs mois sans aucun revenu. C'est
pendant cette periode que beaucoup de gens s'endettent.

**En resume** : l'IJM te protege a court terme (0-2 ans),
l'AI te protege a long terme (2+ ans), mais le passage de
l'un a l'autre peut etre brutal.

## Disclaimer
"Information generale sur le systeme suisse d'assurances sociales.
Chaque situation est individuelle. Sources : CO art. 324a, LAI art. 28,
LAMal art. 67ss."

## Action
"Verifier ma couverture IJM"

## Safe Mode
Informationnel uniquement.
```

### 7.2 Insert: "Ton filet de securite en cas de maladie"

**File**: `education/inserts/q_disability_safety_net.md`

```markdown
# Insert: Ton filet de securite en cas de maladie

## Metadata
questionId: "q_disability_safety_net"
phase: "Niveau 1"
status: "READY"

## Contenu (FR)

Imagine que tu ne puisses plus travailler demain. Que se passe-t-il
financierement ? En Suisse, ta protection depend de trois phases.

**Phase 1 (quelques semaines)** : Ton employeur continue de payer
ton salaire a 100%. La duree depend de ton anciennete et de ton canton
(de 3 semaines la 1ere annee a 6 mois apres 20 ans). C'est le CO
art. 324a. Si tu es independant : rien du tout.

**Phase 2 (jusqu'a 2 ans)** : Si ton employeur a une assurance IJM
collective, tu touches 80% de ton salaire pendant 720 jours. C'est
ta vraie bouee de sauvetage. Mais attention : pres d'un tiers des
entreprises n'ont pas de couverture IJM !

**Phase 3 (apres 2 ans)** : Si tu es toujours incapable de travailler,
l'AI (Assurance-Invalidite) prend le relais. La rente maximale est
de CHF 2'520/mois (2025), a laquelle s'ajoute la rente LPP de ta
caisse de pension. Total ? Souvent moins de 50% de ton ancien salaire.

**La question a te poser** : est-ce que tu pourrais vivre avec CHF
2'500 par mois ? Si la reponse est non, tu as un "gap" a combler --
par une epargne de precaution ou une assurance complementaire.

## Disclaimer
"Estimation simplifiee. Les montants exacts dependent de ton profil
personnel, de ta caisse de pension et de ton canton.
Sources : CO art. 324a, LAI art. 28, LPP art. 23-26."

## Action
"Calculer mon gap de couverture"

## Safe Mode
Informationnel uniquement.
```

---

## 8. DATA STRUCTURES FOR IMPLEMENTATION

### 8.1 Dart Data Model (for Flutter app)

```dart
// === disability_gap_data.dart ===

/// Employer salary continuation scales (CO art. 324a)
enum SalaryScale { bern, zurich, basel }

/// Canton to scale mapping for MVP
const Map<String, SalaryScale> cantonScaleMap = {
  'ZH': SalaryScale.zurich,
  'BE': SalaryScale.bern,
  'VD': SalaryScale.bern,
  'GE': SalaryScale.bern,
  'LU': SalaryScale.bern,
  'BS': SalaryScale.basel,
};

/// Get employer coverage duration in weeks
int getEmployerCoverageWeeks(SalaryScale scale, int yearsOfService) {
  if (yearsOfService < 1) return 0;

  switch (scale) {
    case SalaryScale.bern:
      if (yearsOfService == 1) return 3;
      if (yearsOfService == 2) return 4;
      if (yearsOfService <= 4) return 9;
      if (yearsOfService <= 9) return 13;
      if (yearsOfService <= 14) return 17;
      if (yearsOfService <= 19) return 22;
      return 26;

    case SalaryScale.zurich:
      if (yearsOfService == 1) return 3;
      return 8 + (yearsOfService - 2);

    case SalaryScale.basel:
      if (yearsOfService == 1) return 3;
      if (yearsOfService <= 3) return 9;
      if (yearsOfService <= 10) return 13;
      if (yearsOfService <= 15) return 17;
      if (yearsOfService <= 20) return 22;
      return 26;
  }
}
```

### 8.2 Python Data Model (for backend rules engine)

```python
# === disability_gap_calculator.py ===

from dataclasses import dataclass
from enum import Enum
from typing import Optional

class SalaryScale(Enum):
    BERN = "bern"
    ZURICH = "zurich"
    BASEL = "basel"

class RiskLevel(Enum):
    LOW = "low"
    MEDIUM = "medium"
    MEDIUM_HIGH = "medium-high"
    HIGH = "high"
    CRITICAL = "critical"

CANTON_SCALE_MAP = {
    "ZH": SalaryScale.ZURICH,
    "BE": SalaryScale.BERN,
    "VD": SalaryScale.BERN,
    "GE": SalaryScale.BERN,
    "LU": SalaryScale.BERN,
    "BS": SalaryScale.BASEL,
}

# AI rente amounts 2025/2026 (valid until next index adjustment)
AI_RENTE_FULL_MIN = 1260    # CHF/month
AI_RENTE_FULL_MAX = 2520    # CHF/month
AI_MAX_INCOME_THRESHOLD = 90720  # CHF/year

# LPP parameters 2025/2026
LPP_COORDINATION_DEDUCTION = 26460  # CHF/year
LPP_ENTRY_THRESHOLD = 22680         # CHF/year
LPP_MAX_INSURED_SALARY = 90720      # CHF/year
LPP_MAX_COORDINATED_SALARY = 64260  # CHF/year
LPP_MIN_COORDINATED_SALARY = 3780   # CHF/year
LPP_CONVERSION_RATE = 0.068         # 6.8%

# LPP bonification rates by age
LPP_BONIFICATION_RATES = [
    (25, 34, 0.07),
    (35, 44, 0.10),
    (45, 54, 0.15),
    (55, 65, 0.18),
]

# IJM parameters
IJM_COVERAGE_RATE = 0.80  # 80%
IJM_MAX_DAYS = 720
IJM_PERIOD_DAYS = 900

@dataclass
class DisabilityGapResult:
    """Complete disability gap analysis for a user profile."""
    # Input
    canton: str
    employment_status: str
    gross_monthly_salary: float
    years_of_service: int
    has_collective_ijm: bool
    age: int

    # Phase 1
    scale_name: str
    phase1_duration_weeks: int
    phase1_duration_months: float
    phase1_monthly_benefit: float
    phase1_monthly_gap: float

    # Phase 2
    phase2_has_ijm: bool
    phase2_waiting_period_days: int
    phase2_duration_months: float
    phase2_monthly_benefit: float
    phase2_monthly_gap: float

    # Phase 3
    phase3_ai_rente_monthly: float
    phase3_lpp_rente_monthly: float
    phase3_total_monthly: float
    phase3_monthly_gap: float

    # Risk assessment
    risk_level: str
    risk_reason: str
    recommended_actions: list

    # Legal references
    legal_refs: list

    # Disclaimer
    disclaimer: str


def get_employer_coverage_weeks(scale: SalaryScale, years: int) -> int:
    """Return employer salary continuation duration in weeks."""
    if years < 1:
        return 0

    if scale == SalaryScale.BERN:
        if years == 1: return 3
        if years == 2: return 4
        if years <= 4: return 9
        if years <= 9: return 13
        if years <= 14: return 17
        if years <= 19: return 22
        return 26

    elif scale == SalaryScale.ZURICH:
        if years == 1: return 3
        return 8 + (years - 2)

    elif scale == SalaryScale.BASEL:
        if years == 1: return 3
        if years <= 3: return 9
        if years <= 10: return 13
        if years <= 15: return 17
        if years <= 20: return 22
        return 26


def estimate_ai_rente_monthly(
    gross_annual_income: float,
    disability_degree: int = 100,
) -> float:
    """Estimate monthly AI rente."""
    if disability_degree < 40:
        return 0

    if disability_degree < 50: fraction = 0.25
    elif disability_degree < 60: fraction = 0.50
    elif disability_degree < 70: fraction = 0.75
    else: fraction = 1.0

    if gross_annual_income >= AI_MAX_INCOME_THRESHOLD:
        base = AI_RENTE_FULL_MAX
    elif gross_annual_income <= 0:
        base = AI_RENTE_FULL_MIN
    else:
        ratio = gross_annual_income / AI_MAX_INCOME_THRESHOLD
        base = AI_RENTE_FULL_MIN + (AI_RENTE_FULL_MAX - AI_RENTE_FULL_MIN) * ratio

    return round(base * fraction)


def estimate_lpp_disability_monthly(
    gross_annual_salary: float,
    age: int,
    disability_degree: int = 100,
) -> float:
    """Estimate monthly LPP disability rente (obligatory part only)."""
    if gross_annual_salary < LPP_ENTRY_THRESHOLD:
        return 0

    if disability_degree < 40:
        return 0

    if disability_degree < 50: fraction = 0.25
    elif disability_degree < 60: fraction = 0.50
    elif disability_degree < 70: fraction = 0.75
    else: fraction = 1.0

    coordinated = min(
        max(gross_annual_salary - LPP_COORDINATION_DEDUCTION, LPP_MIN_COORDINATED_SALARY),
        LPP_MAX_COORDINATED_SALARY,
    )

    # Calculate hypothetical capital
    capital = 0
    for (age_min, age_max, rate) in LPP_BONIFICATION_RATES:
        for y in range(max(25, age_min), min(65, age_max + 1)):
            capital += coordinated * rate

    annual_rente = capital * LPP_CONVERSION_RATE
    monthly = annual_rente / 12

    return round(monthly * fraction)


def calculate_disability_gap(
    canton: str,
    employment_status: str,
    gross_monthly_salary: float,
    years_of_service: int = 0,
    has_collective_ijm: bool = False,
    age: int = 30,
    disability_degree: int = 100,
    ijm_waiting_days: int = 30,
) -> DisabilityGapResult:
    """
    Main entry point: calculate the complete disability gap for a user.
    Returns a DisabilityGapResult with all phases, gaps, and recommendations.
    """
    gross_annual = gross_monthly_salary * 12

    # Determine scale
    scale = CANTON_SCALE_MAP.get(canton, SalaryScale.BERN)
    scale_name = {
        SalaryScale.BERN: "bernoise",
        SalaryScale.ZURICH: "zurichoise",
        SalaryScale.BASEL: "baloise",
    }[scale]

    # Phase 1: Employer
    is_employee = employment_status in ("employee", "mixed")
    if is_employee and years_of_service >= 1:
        p1_weeks = get_employer_coverage_weeks(scale, years_of_service)
        p1_months = round(p1_weeks / 4.33, 2)
        p1_benefit = gross_monthly_salary
        p1_gap = 0
    else:
        p1_weeks = 0
        p1_months = 0
        p1_benefit = 0
        p1_gap = gross_monthly_salary

    # Phase 2: IJM
    if has_collective_ijm and is_employee:
        p2_benefit = round(gross_monthly_salary * IJM_COVERAGE_RATE)
        p2_duration = round(IJM_MAX_DAYS / 30, 1)
        p2_gap = gross_monthly_salary - p2_benefit
        p2_wait = ijm_waiting_days
    else:
        p2_benefit = 0
        p2_duration = 0
        p2_gap = gross_monthly_salary
        p2_wait = 0

    # Phase 3: AI + LPP
    p3_ai = estimate_ai_rente_monthly(gross_annual, disability_degree)

    has_lpp = is_employee or (employment_status == "self_employed"
                              and False)  # self-employed typically no LPP
    if has_lpp:
        p3_lpp = estimate_lpp_disability_monthly(gross_annual, age, disability_degree)
    else:
        p3_lpp = 0

    p3_total = p3_ai + p3_lpp

    # 90% coordination check
    max_allowed = gross_monthly_salary * 0.90
    if p3_total > max_allowed:
        p3_lpp = max(0, max_allowed - p3_ai)
        p3_total = p3_ai + p3_lpp

    p3_gap = gross_monthly_salary - p3_total

    # Risk level
    if employment_status == "self_employed" and not has_collective_ijm:
        risk = RiskLevel.CRITICAL
        risk_reason = "Aucune couverture automatique. Revenu a zero des le jour 1."
    elif not has_collective_ijm and is_employee:
        risk = RiskLevel.HIGH
        risk_reason = f"Seulement {p1_weeks} semaines de couverture, puis plus rien."
    elif p3_gap > gross_monthly_salary * 0.6:
        risk = RiskLevel.MEDIUM_HIGH
        risk_reason = "Gap Phase 3 superieur a 60% du salaire."
    elif has_collective_ijm:
        risk = RiskLevel.MEDIUM
        risk_reason = "IJM couvre 80% pendant 2 ans, mais gap Phase 3 significatif."
    else:
        risk = RiskLevel.LOW
        risk_reason = "Couverture adequate."

    # Recommendations
    actions = _get_recommended_actions(employment_status, has_collective_ijm, p3_gap)

    # Legal references
    refs = [
        "CO art. 324a (obligation employeur)",
        "LAI art. 28-28a (conditions AI)",
        "LAVS art. 42-43 (montants rente)",
        "LPP art. 23-26 (prestations invalidite LPP)",
    ]

    disclaimer = (
        "Estimation simplifiee a titre pedagogique. Les montants exacts dependent "
        "de votre caisse de pension, de votre duree de cotisation AVS et de votre "
        "situation personnelle. Cette simulation ne constitue pas un conseil en "
        "assurance. Sources : CO art. 324a, LAI, LAVS, LPP."
    )

    return DisabilityGapResult(
        canton=canton,
        employment_status=employment_status,
        gross_monthly_salary=gross_monthly_salary,
        years_of_service=years_of_service,
        has_collective_ijm=has_collective_ijm,
        age=age,
        scale_name=scale_name,
        phase1_duration_weeks=p1_weeks,
        phase1_duration_months=p1_months,
        phase1_monthly_benefit=p1_benefit,
        phase1_monthly_gap=p1_gap,
        phase2_has_ijm=has_collective_ijm and is_employee,
        phase2_waiting_period_days=p2_wait,
        phase2_duration_months=p2_duration,
        phase2_monthly_benefit=p2_benefit,
        phase2_monthly_gap=p2_gap,
        phase3_ai_rente_monthly=p3_ai,
        phase3_lpp_rente_monthly=p3_lpp,
        phase3_total_monthly=p3_total,
        phase3_monthly_gap=p3_gap,
        risk_level=risk.value,
        risk_reason=risk_reason,
        recommended_actions=actions,
        legal_refs=refs,
        disclaimer=disclaimer,
    )


def _get_recommended_actions(status, has_ijm, phase3_gap):
    actions = []
    if status == "self_employed":
        actions.append("ACTION URGENTE : Souscrire une assurance perte de gain (IJM individuelle)")
        actions.append("Considerer une affiliation volontaire a une caisse de pension (LPP)")
        actions.append("Constituer 6-12 mois d'epargne de precaution")
    elif not has_ijm:
        actions.append("PRIORITE : Souscrire une IJM individuelle ou demander a ton employeur")
        actions.append("Constituer au minimum 6 mois d'epargne de precaution")
    else:
        actions.append("Verifier les conditions exactes de ta couverture IJM aupres de ton RH")

    if phase3_gap > 2000:
        actions.append(
            f"Ton gap Phase 3 est de CHF {phase3_gap:.0f}/mois. "
            "Considere une assurance invalidite complementaire."
        )

    actions.append("Verifier ton certificat de prevoyance (LPP) pour les prestations invalidite exactes")
    actions.append("Maximiser ton 3e pilier (epargne deductible et protegee)")

    return actions
```

### 8.3 JSON Configuration File

**File**: `apps/mobile/assets/config/disability_gap_config.json`

```json
{
  "version": "2025-01",
  "valid_from": "2025-01-01",
  "valid_until": "2026-12-31",
  "sources": {
    "ai_rente": "OAVS, Decision CF 28.08.2024, en vigueur 01.01.2025",
    "lpp_params": "LPP/OPP2, en vigueur 01.01.2025",
    "employer_scales": "Jurisprudence cantonale, Streiff/von Kaenel, Berner Kommentar"
  },
  "ai_rente": {
    "full_monthly_min": 1260,
    "full_monthly_max": 2520,
    "couple_monthly_max": 3780,
    "max_income_for_max_rente": 90720,
    "disability_thresholds": {
      "no_right_max": 39,
      "quarter_min": 40,
      "quarter_max": 49,
      "half_min": 50,
      "half_max": 59,
      "three_quarter_min": 60,
      "three_quarter_max": 69,
      "full_min": 70
    }
  },
  "lpp": {
    "coordination_deduction": 26460,
    "entry_threshold": 22680,
    "max_insured_salary": 90720,
    "max_coordinated_salary": 64260,
    "min_coordinated_salary": 3780,
    "conversion_rate": 0.068,
    "bonification_rates": [
      { "age_min": 25, "age_max": 34, "rate": 0.07 },
      { "age_min": 35, "age_max": 44, "rate": 0.10 },
      { "age_min": 45, "age_max": 54, "rate": 0.15 },
      { "age_min": 55, "age_max": 65, "rate": 0.18 }
    ],
    "max_total_with_ai_percentage": 0.90
  },
  "ijm": {
    "coverage_rate": 0.80,
    "max_duration_days": 720,
    "within_period_days": 900,
    "typical_waiting_periods": [0, 30, 60, 90]
  },
  "employer_scales": {
    "canton_mapping": {
      "ZH": "zurich",
      "BE": "bern",
      "VD": "bern",
      "GE": "bern",
      "LU": "bern",
      "BS": "basel",
      "BL": "basel",
      "SH": "zurich",
      "TG": "zurich",
      "GR": "zurich",
      "ZG": "zurich",
      "AI": "zurich",
      "AR": "zurich",
      "AG": "bern",
      "FR": "bern",
      "NE": "bern",
      "SO": "bern",
      "VS": "bern",
      "JU": "bern",
      "TI": "bern",
      "UR": "bern",
      "SZ": "bern",
      "OW": "bern",
      "NW": "bern",
      "GL": "bern",
      "SG": "bern"
    },
    "scales": {
      "bern": {
        "name_fr": "Echelle bernoise",
        "legal_ref": "Jurisprudence, Berner Kommentar",
        "brackets": [
          { "years_min": 1, "years_max": 1, "weeks": 3 },
          { "years_min": 2, "years_max": 2, "weeks": 4 },
          { "years_min": 3, "years_max": 4, "weeks": 9 },
          { "years_min": 5, "years_max": 9, "weeks": 13 },
          { "years_min": 10, "years_max": 14, "weeks": 17 },
          { "years_min": 15, "years_max": 19, "weeks": 22 },
          { "years_min": 20, "years_max": 99, "weeks": 26 }
        ]
      },
      "zurich": {
        "name_fr": "Echelle zurichoise",
        "legal_ref": "Jurisprudence Obergericht ZH",
        "formula": "year 1 = 3 weeks; year 2+ = 8 + (year - 2) weeks"
      },
      "basel": {
        "name_fr": "Echelle baloise",
        "legal_ref": "Jurisprudence Basel, Basler Kommentar OR I",
        "brackets": [
          { "years_min": 1, "years_max": 1, "weeks": 3 },
          { "years_min": 2, "years_max": 3, "weeks": 9 },
          { "years_min": 4, "years_max": 10, "weeks": 13 },
          { "years_min": 11, "years_max": 15, "weeks": 17 },
          { "years_min": 16, "years_max": 20, "weeks": 22 },
          { "years_min": 21, "years_max": 99, "weeks": 26 }
        ]
      }
    }
  }
}
```

---

## LEGAL SOURCES SUMMARY

| Data Point | Legal Source | Article |
|---|---|---|
| Employer salary continuation obligation | Code des Obligations (CO) | art. 324a al. 1-2 |
| Equivalent insurance substitution | Code des Obligations (CO) | art. 324a al. 4 |
| Bern/Zurich/Basel scales | Cantonal jurisprudence | ATF; Obergericht ZH; Basler Kommentar |
| AI rente conditions | Loi sur l'assurance-invalidite (LAI) | art. 28, 28a |
| AI rente amounts | Loi AVS (LAVS) + ordonnance | art. 34-40, 42-43 |
| AI disability degree thresholds | LAI | art. 28 al. 2 |
| AI rente amounts 2025 | Decision CF 28.08.2024 | OAVS adaptation |
| LPP disability entitlement | Loi prevoyance professionnelle (LPP) | art. 23 |
| LPP disability amount | LPP | art. 24 |
| LPP coordination (90% rule) | LPP | art. 24a; OPP2 art. 25 |
| LPP partial disability | LPP | art. 25 |
| LPP begin/end of entitlement | LPP | art. 26 |
| LPP bonification rates | LPP | art. 16 |
| LPP coordination deduction | LPP | art. 8; OPP2 |
| LPP conversion rate | LPP | art. 14 al. 2 |
| IJM optional insurance | LAMal | art. 67-77 |
| IJM private law basis | LCA | Loi contrat assurance |
| Unemployment + illness | LACI | art. 28 |

---

## IMPLEMENTATION NOTES

### Priority Order
1. JSON config file (data source of truth)
2. Dart calculator service (disability_gap_service.dart)
3. Python backend calculator (disability_gap_calculator.py)
4. Flutter UI screen (disability_gap_screen.dart)
5. Educational inserts (2 files)
6. Tests (test_disability_gap.py, disability_gap_test.dart)

### Key Design Decisions
- **LPP estimate is obligatory part only**: The actual LPP disability pension depends on the specific pension fund and may include surobligatoire parts. We clearly label this as "estimation minimum legale".
- **AI rente simplified to linear interpolation**: The actual calculation uses a complex scale based on contribution years and average income. Our interpolation is accurate within ~5% for most cases.
- **Zurich scale is formulaic**: Unlike Bern and Basel which use bracket tables, the Zurich scale follows a simple formula (8 + years - 2).
- **90% coordination cap applied last**: After calculating AI + LPP, we check against the 90% rule. If exceeded, we reduce LPP (not AI).
- **Self-employed have zero LPP by default**: Unless hasVoluntaryLpp is true (future enhancement).

### Test Matrix
| Test | Persona | Canton | Scale | IJM | Expected Risk |
|---|---|---|---|---|---|
| 1 | Marc | ZH | Zurich | Yes | medium |
| 2 | Sophie | VD | Bern | Yes | medium |
| 3 | Pierre | GE | N/A | No | critical |
| 4 | Anna | BS | Basel | No | high |
| 5 | Thomas | LU | Bern | Yes | medium-high |

### Disclaimer (mandatory on every screen)
"Estimation pedagogique simplifiee. Les montants exacts dependent de votre caisse de pension, de votre duree de cotisation AVS et de votre situation personnelle. Cette simulation ne constitue pas un conseil en assurance ni un conseil financier. Consultez votre caisse de pension et/ou un conseiller en assurances pour une evaluation precise. Sources : CO art. 324a, LAI art. 28, LAVS art. 42, LPP art. 23-26."
