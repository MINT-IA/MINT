"""
Minimal Profile Service — Compute a financial snapshot from 3 inputs.

Sprint S31 — Onboarding Redesign.

Given age, gross_salary, and canton (+ optional enrichment fields),
produces a complete financial snapshot with:
- Projected AVS monthly rente
- Projected LPP capital and monthly rente
- Estimated replacement ratio at retirement
- Tax saving potential via pillar 3a
- Liquidity runway in months
- Confidence score based on data completeness

All constants are imported from app.constants.social_insurance (NEVER hardcoded).

Sources:
    - LAVS art. 21-29, 34, 40 (rente AVS, duree cotisation, reduction)
    - LPP art. 7, 8, 14, 15-16 (seuil, coordination, conversion, bonifications)
    - OPP3 art. 7 (plafond 3a: 7'258 CHF avec LPP)
    - LIFD art. 38 (imposition du capital de prevoyance)

Rules:
    - NEVER use banned terms: "garanti", "certain", "assure", "sans risque",
      "optimal", "meilleur", "parfait", "conseiller", "tu devrais", "tu dois"
    - Educational tone, informal "tu", inclusive language
    - Disclaimer mandatory on every result
"""

from typing import List

from app.constants.social_insurance import (
    AVS_RAMD_MIN,
    AVS_RAMD_MAX,
    AVS_RENTE_MAX_MENSUELLE,
    AVS_RENTE_MIN_MENSUELLE,
    AVS_DUREE_COTISATION_COMPLETE,
    AVS_AGE_REFERENCE_HOMME,
    LPP_SEUIL_ENTREE,
    LPP_DEDUCTION_COORDINATION,
    LPP_SALAIRE_COORDONNE_MIN,
    LPP_SALAIRE_COORDONNE_MAX,
    LPP_TAUX_CONVERSION_MIN,
    LPP_TAUX_INTERET_MIN,
    PILIER_3A_PLAFOND_AVEC_LPP,
    TAUX_IMPOT_RETRAIT_CAPITAL,
    TAUX_IMPOT_RETRAIT_CAPITAL_DEFAULT,
    LPP_CONVERSION_RATE_COMPLEMENTAIRE,
    get_lpp_bonification_rate,
)

from app.services.onboarding.onboarding_models import (
    MinimalProfileInput,
    MinimalProfileResult,
)


# ═══════════════════════════════════════════════════════════════════════════════
# Constants — derived from social_insurance.py
# ═══════════════════════════════════════════════════════════════════════════════

# AVS linear interpolation boundaries (RAMD) — from social_insurance.py
_AVS_RAMD_LOW: float = AVS_RAMD_MIN
_AVS_RAMD_HIGH: float = AVS_RAMD_MAX

# Approximate net salary factor (Swiss average: ~87% of gross after social deductions)
_NET_SALARY_FACTOR: float = 0.87

# Approximate monthly expenses as fraction of net salary
_EXPENSES_FACTOR: float = 0.85

# Retirement reference age
_RETIREMENT_AGE: int = AVS_AGE_REFERENCE_HOMME  # 65

# Default marginal tax rate for middle incomes (proxy)
_DEFAULT_MARGINAL_TAX_RATE: float = 0.25

# LPP interest rate
_LPP_INTEREST_RATE: float = LPP_TAUX_INTERET_MIN / 100.0  # 0.0125

# LPP conversion rate
_LPP_CONVERSION_RATE: float = LPP_TAUX_CONVERSION_MIN / 100.0  # 0.068

# LPP blended conversion rate for "complementaire" caisses — from social_insurance.py
_LPP_CONVERSION_RATE_COMPLEMENTAIRE: float = LPP_CONVERSION_RATE_COMPLEMENTAIRE

# Debt: monthly estimation factor when only total_debts is provided
# Assumes ~0.5% of total debt as monthly service (conservative proxy)
_DEBT_MONTHLY_ESTIMATION_FACTOR: float = 0.005

# Confidence scoring: base score with only 3 inputs, bonus per enrichment field
_CONFIDENCE_BASE: float = 30.0
_CONFIDENCE_BONUS_PER_FIELD: float = 10.0


# ═══════════════════════════════════════════════════════════════════════════════
# Compliance constants
# ═══════════════════════════════════════════════════════════════════════════════

_DISCLAIMER = (
    "Outil educatif simplifie. Ne constitue pas un conseil financier (LSFin). "
    "Consulte un\u00b7e specialiste pour une analyse personnalisee."
)

_SOURCES = [
    "LAVS art. 21-29 (rente AVS)",
    "LPP art. 14-16 (conversion, bonifications vieillesse)",
    "LIFD art. 38 (imposition du capital)",
    "OPP3 art. 7 (plafond 3a)",
    "CO art. 319ss (charges et dettes sur revenu disponible)",
]


# ═══════════════════════════════════════════════════════════════════════════════
# Pure functions
# ═══════════════════════════════════════════════════════════════════════════════

def _estimate_avs_monthly(gross_salary: float, contribution_years: int) -> float:
    """Estimate monthly AVS rente based on RAMD and contribution years.

    Uses LAVS art. 34 formula:
    - If RAMD <= 14'700 CHF: minimum rente (1'260 CHF/month)
    - If RAMD >= 88'200 CHF: maximum rente (2'520 CHF/month)
    - Between: linear interpolation

    Then apply reduction for incomplete contribution years (< 44).

    Args:
        gross_salary: Annual gross salary (used as proxy for RAMD).
        contribution_years: Number of AVS contribution years.

    Returns:
        Estimated monthly AVS rente (CHF).
    """
    if gross_salary <= 0:
        return 0.0

    # Determine full rente from RAMD (linear interpolation)
    if gross_salary <= _AVS_RAMD_LOW:
        full_rente = AVS_RENTE_MIN_MENSUELLE
    elif gross_salary >= _AVS_RAMD_HIGH:
        full_rente = AVS_RENTE_MAX_MENSUELLE
    else:
        # Linear interpolation between min and max
        ratio = (gross_salary - _AVS_RAMD_LOW) / (_AVS_RAMD_HIGH - _AVS_RAMD_LOW)
        full_rente = AVS_RENTE_MIN_MENSUELLE + ratio * (
            AVS_RENTE_MAX_MENSUELLE - AVS_RENTE_MIN_MENSUELLE
        )

    # Apply reduction for incomplete contribution years
    complete_years = AVS_DUREE_COTISATION_COMPLETE  # 44
    effective_years = min(contribution_years, complete_years)
    if effective_years <= 0:
        return 0.0
    reduction_factor = effective_years / complete_years

    return round(full_rente * reduction_factor, 2)


def _project_lpp_capital(
    current_age: int,
    gross_salary: float,
    existing_lpp: float,
    retirement_age: int = _RETIREMENT_AGE,
) -> float:
    """Project LPP capital at retirement using bonification rates.

    Projects year by year from current_age to retirement_age:
    - Computes coordinated salary (max capped)
    - Applies age-based bonification rate (LPP art. 16)
    - Applies minimum interest rate on accumulated capital

    Args:
        current_age: Current age of the user.
        gross_salary: Annual gross salary.
        existing_lpp: Current LPP capital balance.
        retirement_age: Target retirement age (default 65).

    Returns:
        Projected LPP capital at retirement (CHF).
    """
    if gross_salary < LPP_SEUIL_ENTREE:
        # Below LPP entry threshold: no obligatory LPP
        return existing_lpp

    # Coordinated salary
    coordinated_salary = gross_salary - LPP_DEDUCTION_COORDINATION
    coordinated_salary = max(coordinated_salary, LPP_SALAIRE_COORDONNE_MIN)
    coordinated_salary = min(coordinated_salary, LPP_SALAIRE_COORDONNE_MAX)

    capital = existing_lpp
    for age in range(current_age, retirement_age):
        # Annual bonification
        bonification_rate = get_lpp_bonification_rate(age)
        annual_bonification = coordinated_salary * bonification_rate

        # Interest on existing capital
        interest = capital * _LPP_INTEREST_RATE

        capital += annual_bonification + interest

    return round(capital, 2)


def _estimate_lpp_from_age_25(
    current_age: int,
    gross_salary: float,
) -> float:
    """Estimate current LPP capital assuming contributions since age 25.

    Used as default when existing_lpp is not provided.

    Args:
        current_age: Current age of the user.
        gross_salary: Annual gross salary (assumed constant for simplicity).

    Returns:
        Estimated current LPP capital (CHF).
    """
    if current_age <= 25 or gross_salary < LPP_SEUIL_ENTREE:
        return 0.0

    coordinated_salary = gross_salary - LPP_DEDUCTION_COORDINATION
    coordinated_salary = max(coordinated_salary, LPP_SALAIRE_COORDONNE_MIN)
    coordinated_salary = min(coordinated_salary, LPP_SALAIRE_COORDONNE_MAX)

    capital = 0.0
    for age in range(25, current_age):
        bonification_rate = get_lpp_bonification_rate(age)
        annual_bonification = coordinated_salary * bonification_rate
        interest = capital * _LPP_INTEREST_RATE
        capital += annual_bonification + interest

    return round(capital, 2)


def _compute_marginal_tax_rate(gross_salary: float, canton: str) -> float:
    """Approximate marginal tax rate based on cantonal capital tax rates.

    NOTE: This is a rough approximation (capital_tax_rate * 3.5).
    The canonical marginal rate computation is in the mobile
    RetirementTaxCalculator.estimateMarginalRate() using AFC 2024 data.
    This approximation is acceptable for onboarding chiffre-choc
    (educational, with +/-5% tolerance). Final displays in the mobile
    app MUST use RetirementTaxCalculator, not this backend approximation.

    Uses TAUX_IMPOT_RETRAIT_CAPITAL as a proxy for cantonal tax burden,
    scaled by income level.

    Args:
        gross_salary: Annual gross salary.
        canton: Canton code (2 letters).

    Returns:
        Estimated marginal tax rate (0.0 - 0.50).
    """
    base_rate = TAUX_IMPOT_RETRAIT_CAPITAL.get(canton.upper(), TAUX_IMPOT_RETRAIT_CAPITAL_DEFAULT)

    # Scale from capital withdrawal rate to income tax approximation
    # Capital withdrawal rates are ~5-8%, income marginal rates are ~15-40%
    # Use a multiplier of ~3.5x as rough proxy (see note above)
    income_factor = base_rate * 3.5

    # Adjust for income level
    if gross_salary < 50_000:
        income_factor *= 0.70
    elif gross_salary < 80_000:
        income_factor *= 0.85
    elif gross_salary < 120_000:
        income_factor *= 1.00
    elif gross_salary < 200_000:
        income_factor *= 1.15
    else:
        income_factor *= 1.30

    # Clamp to reasonable range
    return round(min(max(income_factor, 0.10), 0.45), 4)


def _compute_confidence_score(estimated_fields: List[str]) -> float:
    """Compute confidence score based on number of estimated (defaulted) fields.

    Base score: 30% with only 3 required inputs (age, salary, canton).
    Each enrichment field provided adds ~10% confidence.

    The 7 optional fields are:
    - household_type (+10%)
    - current_savings (+10%)
    - is_property_owner (+10%)
    - existing_3a (+10%)
    - existing_lpp (+10%)
    - lpp_caisse_type (+10%)
    - monthly_debt_service (+10%)

    When all 7 are provided: 30 + 70 = 100%.

    Args:
        estimated_fields: List of field names that used default values.

    Returns:
        Confidence score (0-100).
    """
    total_optional_fields = 7
    fields_provided = total_optional_fields - len(estimated_fields)
    score = _CONFIDENCE_BASE + (fields_provided * _CONFIDENCE_BONUS_PER_FIELD)
    return round(min(max(score, 0.0), 100.0), 1)


def _build_enrichment_prompts(estimated_fields: List[str]) -> List[str]:
    """Build user-facing enrichment prompts based on which fields are estimated.

    Each prompt uses informal "tu" and is in French.

    Args:
        estimated_fields: List of field names that used default values.

    Returns:
        List of enrichment prompt strings.
    """
    prompts_map = {
        "household_type": (
            "Indique ta situation familiale pour affiner l'estimation "
            "de tes charges et de ta rente AVS couple."
        ),
        "current_savings": (
            "Renseigne ton epargne actuelle pour une estimation "
            "plus precise de ta reserve de liquidite."
        ),
        "is_property_owner": (
            "Indique si tu es proprietaire pour prendre en compte "
            "les charges hypothecaires et la valeur locative."
        ),
        "existing_3a": (
            "Ajoute le solde de ton 3e pilier pour affiner "
            "l'estimation de ton epargne retraite."
        ),
        "existing_lpp": (
            "Renseigne ton avoir LPP actuel (visible sur ton certificat "
            "de prevoyance) pour une projection de retraite plus fiable."
        ),
        "lpp_caisse_type": (
            "Indique le type de ta caisse LPP (base ou complementaire) "
            "pour un taux de conversion plus realiste."
        ),
        "monthly_debt_service": (
            "Renseigne tes charges de dette mensuelles pour integrer "
            "leur impact sur ton revenu de retraite disponible."
        ),
    }

    return [prompts_map[f] for f in estimated_fields if f in prompts_map]


# ═══════════════════════════════════════════════════════════════════════════════
# Main function
# ═══════════════════════════════════════════════════════════════════════════════

def compute_minimal_profile(input: MinimalProfileInput) -> MinimalProfileResult:
    """Compute a full financial snapshot from minimal inputs.

    Given 3 required fields (age, gross_salary, canton) and up to 7 optional
    enrichment fields, produces projected retirement income, tax savings,
    liquidity, and a confidence score.

    All formulas use constants from app.constants.social_insurance.

    Args:
        input: MinimalProfileInput with required + optional fields.

    Returns:
        MinimalProfileResult with projections, confidence, and compliance fields.

    Raises:
        ValueError: If age, salary, or canton are invalid.
    """
    # ── Validation ──────────────────────────────────────────────────────────
    if input.age < 18 or input.age > 70:
        raise ValueError(f"Age must be between 18 and 70, got {input.age}")
    if input.gross_salary < 0:
        raise ValueError(f"Gross salary must be >= 0, got {input.gross_salary}")
    canton = input.canton.upper()
    if canton not in TAUX_IMPOT_RETRAIT_CAPITAL:
        raise ValueError(f"Unknown canton: {canton}")

    # ── Track estimated fields ──────────────────────────────────────────────
    estimated_fields: List[str] = []

    # household_type
    household_type = input.household_type
    if household_type is None:
        household_type = "single"
        estimated_fields.append("household_type")

    # current_savings
    current_savings = input.current_savings
    if current_savings is None:
        current_savings = max(0.0, (input.age - 25) * input.gross_salary * 0.05)
        estimated_fields.append("current_savings")

    # is_property_owner
    is_property_owner = input.is_property_owner
    if is_property_owner is None:
        is_property_owner = False
        estimated_fields.append("is_property_owner")

    # existing_3a
    existing_3a = input.existing_3a
    if existing_3a is None:
        existing_3a = 0.0
        estimated_fields.append("existing_3a")

    # existing_lpp
    existing_lpp = input.existing_lpp
    if existing_lpp is None:
        existing_lpp = _estimate_lpp_from_age_25(input.age, input.gross_salary)
        estimated_fields.append("existing_lpp")

    # lpp_caisse_type
    if input.lpp_caisse_type is None:
        estimated_fields.append("lpp_caisse_type")

    # monthly_debt_service (counts as provided if either debt field is given)
    if input.monthly_debt_service is None and input.total_debts is None:
        estimated_fields.append("monthly_debt_service")

    # ── AVS projection ──────────────────────────────────────────────────────
    # Contribution years: from age 21 to retirement (65), capped at 44
    years_until_retirement = max(0, _RETIREMENT_AGE - input.age)
    current_contribution_years = max(0, min(input.age - 21, AVS_DUREE_COTISATION_COMPLETE))
    total_contribution_years = min(
        current_contribution_years + years_until_retirement,
        AVS_DUREE_COTISATION_COMPLETE,
    )
    projected_avs_monthly = _estimate_avs_monthly(input.gross_salary, total_contribution_years)

    # ── LPP projection ──────────────────────────────────────────────────────
    projected_lpp_capital = _project_lpp_capital(
        current_age=input.age,
        gross_salary=input.gross_salary,
        existing_lpp=existing_lpp,
        retirement_age=_RETIREMENT_AGE,
    )
    # Select conversion rate based on caisse type
    if input.lpp_caisse_type == "complementaire":
        lpp_conversion_rate = _LPP_CONVERSION_RATE_COMPLEMENTAIRE
    else:
        # None or "base" → standard obligatory rate
        lpp_conversion_rate = _LPP_CONVERSION_RATE
    projected_lpp_monthly = round(projected_lpp_capital * lpp_conversion_rate / 12, 2)

    # ── Monthly expenses estimate ───────────────────────────────────────────
    net_salary_monthly = (input.gross_salary * _NET_SALARY_FACTOR) / 12
    estimated_monthly_expenses = round(net_salary_monthly * _EXPENSES_FACTOR, 2)

    # ── Retirement income ───────────────────────────────────────────────────
    estimated_monthly_retirement = round(projected_avs_monthly + projected_lpp_monthly, 2)

    # ── Debt impact (anti-double-counting: subtract from retirement income,
    #    NOT added to expenses) ────────────────────────────────────────────
    # Priority: monthly_debt_service > total_debts estimate
    # If both provided → IGNORE total_debts, use monthly_debt_service
    monthly_debt_impact = 0.0
    if input.monthly_debt_service is not None and input.monthly_debt_service > 0:
        monthly_debt_impact = round(input.monthly_debt_service, 2)
    elif input.total_debts is not None and input.total_debts > 0:
        monthly_debt_impact = round(
            input.total_debts * _DEBT_MONTHLY_ESTIMATION_FACTOR, 2
        )

    # Reduce available retirement income by debt service
    estimated_monthly_retirement = round(
        max(0.0, estimated_monthly_retirement - monthly_debt_impact), 2
    )

    # ── Replacement ratio (vs gross salary, standard Swiss definition) ─────
    gross_monthly_salary = input.gross_salary / 12
    if gross_monthly_salary > 0:
        estimated_replacement_ratio = round(
            estimated_monthly_retirement / gross_monthly_salary, 4
        )
    else:
        estimated_replacement_ratio = 0.0

    # ── Retirement gap (vs gross salary) ──────────────────────────────────
    retirement_gap_monthly = round(
        max(0.0, gross_monthly_salary - estimated_monthly_retirement), 2
    )

    # ── Tax saving 3a ───────────────────────────────────────────────────────
    marginal_tax_rate = _compute_marginal_tax_rate(input.gross_salary, canton)
    tax_saving_3a = round(marginal_tax_rate * PILIER_3A_PLAFOND_AVEC_LPP, 2)

    # ── Liquidity ───────────────────────────────────────────────────────────
    if estimated_monthly_expenses > 0:
        months_liquidity = round(current_savings / estimated_monthly_expenses, 2)
    else:
        months_liquidity = 0.0

    # ── Confidence & enrichment ─────────────────────────────────────────────
    confidence_score = _compute_confidence_score(estimated_fields)
    enrichment_prompts = _build_enrichment_prompts(estimated_fields)

    # ── Build result ────────────────────────────────────────────────────────
    return MinimalProfileResult(
        projected_avs_monthly=projected_avs_monthly,
        projected_lpp_capital=projected_lpp_capital,
        projected_lpp_monthly=projected_lpp_monthly,
        estimated_replacement_ratio=estimated_replacement_ratio,
        estimated_monthly_retirement=estimated_monthly_retirement,
        estimated_monthly_expenses=estimated_monthly_expenses,
        retirement_gap_monthly=retirement_gap_monthly,
        tax_saving_3a=tax_saving_3a,
        existing_3a=existing_3a,
        marginal_tax_rate=marginal_tax_rate,
        months_liquidity=months_liquidity,
        monthly_debt_impact=monthly_debt_impact,
        confidence_score=confidence_score,
        estimated_fields=estimated_fields,
        archetype="swiss_native",
        disclaimer=_DISCLAIMER,
        sources=list(_SOURCES),
        enrichment_prompts=enrichment_prompts,
    )
