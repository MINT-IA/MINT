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

from typing import List, Optional

from app.constants.social_insurance import (
    AVS_DUREE_COTISATION_COMPLETE,
    AVS_AGE_REFERENCE_HOMME,
    avs_reference_age,
    rente_from_ramd,
    LPP_SEUIL_ENTREE,
    LPP_DEDUCTION_COORDINATION,
    LPP_SALAIRE_COORDONNE_MIN,
    LPP_SALAIRE_COORDONNE_MAX,
    LPP_TAUX_CONVERSION_MIN,
    LPP_TAUX_INTERET_MIN,
    PILIER_3A_PLAFOND_AVEC_LPP,
    PILIER_3A_PLAFOND_SANS_LPP,
    TAUX_IMPOT_RETRAIT_CAPITAL,
    LPP_CONVERSION_RATE_COMPLEMENTAIRE,
    get_lpp_bonification_rate,
)

from app.services.onboarding.onboarding_models import (
    MinimalProfileInput,
    MinimalProfileResult,
)


# ═══════════════════════════════════════════════════════════════════════════════
# FIX-092: Archetype detection
# ═══════════════════════════════════════════════════════════════════════════════

_US_CODES = {"US", "USA"}
_EU_CODES = {
    "AT", "BE", "BG", "HR", "CY", "CZ", "DK", "EE", "FI", "FR", "DE", "GR",
    "HU", "IE", "IT", "LV", "LT", "LU", "MT", "NL", "PL", "PT", "RO", "SK",
    "SI", "ES", "SE",
}


def _detect_archetype(input: MinimalProfileInput) -> str:
    """Detect financial archetype from nationality + arrival + employment data.

    See CLAUDE.md §5 — 8 archetypes, each with different AVS/LPP treatment.
    Resolution order (most specific → least specific):
      1. Cross-border worker (permit G) — fiscal/social regime = source taxation
      2. Self-employed (with or without LPP) — 3a ceiling differs (7'258 vs 36'288)
      3. Expat US / FATCA
      4. Returning Swiss (CH national, arrived late)
      5. Native Swiss
      6. Expat EU / non-EU (late arrival without CH nationality)
    """
    nat = (input.nationality_country or "").upper()
    group = (input.nationality_group or "").upper()
    arrival = input.arrival_age
    employment = (input.employment_status or "").lower()
    permit = (input.permit_type or "").upper()

    # Cross-border worker — takes priority: permit G = frontalier regime
    # (source taxation, AVS contributions via employer, no LPP from the
    # first franc, different 3a rules). LAVS art. 1a + CDI transfrontaliers.
    if permit == "G":
        return "cross_border"

    # US citizens → FATCA archetype (regardless of arrival/employment).
    # Must run before self-employed branch because FATCA + independent
    # carries PFIC implications that dominate the 3a discussion.
    if nat in _US_CODES or group == "US":
        return "expat_us"

    # Self-employed — ceiling for 3a is 20% of net income capped at 36'288
    # when the person has NO LPP (OPP3 art. 7 al. 1 let. b); reverts to the
    # salaried ceiling (7'258) as soon as an LPP account exists. Detect LPP
    # presence via existing_lpp > 0 or an explicit caisse type.
    if employment == "self_employed":
        has_lpp = (input.existing_lpp is not None and input.existing_lpp > 0) or bool(
            input.lpp_caisse_type
        )
        return "independent_with_lpp" if has_lpp else "independent_no_lpp"

    # Swiss native: born in CH or arrived < 22 (full contribution years possible)
    if nat == "CH" or group == "CH":
        if arrival is not None and arrival >= 22:
            return "returning_swiss"
        return "swiss_native"

    # No nationality data → default to swiss_native (backward compatible)
    if not nat and not group:
        return "swiss_native"

    # Arrived late → expat (contribution gap)
    is_eu = nat in _EU_CODES or group == "EU"
    if arrival is not None and arrival >= 20:
        return "expat_eu" if is_eu else "expat_non_eu"

    # Arrived young or no arrival data → treat as integrated
    return "expat_eu" if is_eu else "swiss_native"


# ═══════════════════════════════════════════════════════════════════════════════
# Constants — derived from social_insurance.py
# ═══════════════════════════════════════════════════════════════════════════════

# Approximate net salary factor (Swiss average: ~87% of gross after social deductions)
_NET_SALARY_FACTOR: float = 0.87

# Approximate monthly expenses as fraction of net salary
_EXPENSES_FACTOR: float = 0.85

# Retirement reference age — default for when gender is unknown.
# P2-26: Gender-aware via _get_retirement_age() below (AVS21 LAVS art. 21 al. 1).
_RETIREMENT_AGE_DEFAULT: int = AVS_AGE_REFERENCE_HOMME  # 65


def _get_retirement_age(gender: Optional[str], birth_year: int) -> int:
    """Return retirement reference age based on gender AND cohort (AVS21).

    Beads MINT_nosync-xx9 : l'ancienne version servait
    ``AVS_AGE_REFERENCE_FEMME`` = int(64.5) = 64 à TOUTES les femmes —
    faux pour les cohortes 1963+ (65 depuis la réforme AVS 21). L'âge de
    référence dépend de la cohorte, pas d'un scalaire.

    Args:
        gender: "male", "female", or None if unknown.
        birth_year: année de naissance (dérivée de input.age si besoin —
            précision ±1 an sans birth_date, suffisante : seules les
            cohortes 1961-1963 sont sensibles).

    Returns:
        Retirement reference age.
    """
    return avs_reference_age(birth_year, gender == "female")

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

    Uses LAVS art. 34 via the canonical echelle 44 lookup
    (``social_insurance.rente_from_ramd``) — official OFAS table,
    NOT a naive min->max interpolation. Then applies the reduction
    for incomplete contribution years (< 44).

    Args:
        gross_salary: Annual gross salary (used as proxy for RAMD).
        contribution_years: Number of AVS contribution years.

    Returns:
        Estimated monthly AVS rente (CHF).
    """
    if gross_salary <= 0:
        return 0.0

    # Full rente from RAMD via the single canonical echelle 44 function
    # (règle 4 / NEVER #3 — one source of truth per layer, no local copies).
    full_rente = rente_from_ramd(gross_salary)

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
    retirement_age: int = _RETIREMENT_AGE_DEFAULT,
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


def _compute_marginal_tax_rate(
    gross_salary: float, canton: str, *, is_married: bool = False
) -> float:
    """Taux marginal — PENTE du modele fiscal canonique, plus une table.

    `effective_rates_100k` (courbe a 100k x ajustement de revenu x1.3,
    clamp [0.05, 0.45]) donnait 0.1290 pour ZH la ou l'etalon donne
    0.1323 a 100k, et son plancher de 5 % inventait un taux pour des
    revenus quasi non imposes.

    is_married (imposition commune, LIFD art. 9 al. 1) : sans lui, l'onboarding
    servait un taux marginal celibataire meme a un menage marie (vice
    « un seul taux marginal », #1061/#1062).
    """
    from app.services.fiscal.cantonal_comparator import estimate_marginal_rate

    return estimate_marginal_rate(gross_salary, canton.upper(), is_married=is_married)


def _estimate_tax_saving(
    *,
    income: float,
    deduction: float,
    canton: str,
    is_married: bool = False,
) -> float:
    """Economie fiscale — DIFFERENCE d'impot de l'etalon, plus une integration en 10 pas."""
    from app.services.fiscal.cantonal_comparator import estimate_tax_saving

    return estimate_tax_saving(income, deduction, canton.upper(), is_married=is_married)


def _estimate_3a_tax_impact(
    gross_salary: float,
    canton: str,
    *,
    has_lpp: bool,
    household_type: str | None = "single",
) -> tuple[float, float, float]:
    """Estimate 3a tax impact for onboarding.

    Source: OPP3 art. 7 (deductible 3a ceiling).
    Hypotheses: educational marginal-rate estimate from canton + gross salary.

    ``household_type`` (vocabulaire ANGLAIS married/couple/family) est normalise
    via ``rules_engine.is_married_household`` (le BON domaine — pas l'etat civil
    FR) : l'imposition commune (LIFD art. 9 al. 1) abaisse le taux marginal du
    menage marie, donc l'economie 3a et le taux affiches sur l'onboarding.

    Returns:
        (tax_saving_3a, marginal_tax_rate, annual_ceiling).
    """
    from app.services.rules_engine import is_married_household

    is_married = is_married_household(household_type)

    if gross_salary <= 0 or canton.upper() not in TAUX_IMPOT_RETRAIT_CAPITAL:
        ceiling = (
            PILIER_3A_PLAFOND_AVEC_LPP
            if has_lpp
            else min(gross_salary * 0.20, PILIER_3A_PLAFOND_SANS_LPP)
        )
        return 0.0, 0.0, round(max(0.0, ceiling), 2)

    annual_ceiling = (
        PILIER_3A_PLAFOND_AVEC_LPP
        if has_lpp
        else min(gross_salary * 0.20, PILIER_3A_PLAFOND_SANS_LPP)
    )
    marginal_tax_rate = _compute_marginal_tax_rate(
        gross_salary - annual_ceiling / 2,
        canton,
        is_married=is_married,
    )
    return (
        round(
            _estimate_tax_saving(
                income=gross_salary,
                deduction=annual_ceiling,
                canton=canton,
                is_married=is_married,
            ),
            2,
        ),
        marginal_tax_rate,
        round(annual_ceiling, 2),
    )


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
    # ── Resolve age from birth_date when provided ────────────────────────────
    # Review Codex PR #985 : quand birth_date existe, bd.year est LA cohorte
    # exacte — la re-dériver de l'âge bascule la frontière (une femme née le
    # 31.12.1962 a 63 ans mi-2026 -> dérivation 1963 -> 65 ans au lieu de 64).
    birth_year_exact: int | None = None
    if input.birth_date:
        from datetime import date
        try:
            bd = date.fromisoformat(input.birth_date[:10])
            birth_year_exact = bd.year
            today = date.today()
            computed_age = today.year - bd.year - (
                (today.month, today.day) < (bd.month, bd.day)
            )
            input = MinimalProfileInput(
                age=computed_age,
                gross_salary=input.gross_salary,
                canton=input.canton,
                birth_date=input.birth_date,
                household_type=input.household_type,
                current_savings=input.current_savings,
                is_property_owner=input.is_property_owner,
                existing_3a=input.existing_3a,
                existing_lpp=input.existing_lpp,
                lpp_caisse_type=input.lpp_caisse_type,
                total_debts=input.total_debts,
                monthly_debt_service=input.monthly_debt_service,
                stress_type=input.stress_type,
                gender=input.gender,
                nationality_group=input.nationality_group,
                nationality_country=input.nationality_country,
                arrival_age=input.arrival_age,
            )
        except (ValueError, TypeError):
            pass  # Invalid birth_date format — fall back to provided age

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

    # ── P2-26: Gender-aware retirement age (AVS21) ─────────────────────────
    from datetime import date as _date
    retirement_age = _get_retirement_age(
        getattr(input, "gender", None),
        # Cohorte exacte si birth_date fourni ; sinon dérivation par l'âge
        # (±1 an, documenté dans _get_retirement_age).
        birth_year_exact
        if birth_year_exact is not None
        else _date.today().year - input.age,
    )

    # ── AVS projection ──────────────────────────────────────────────────────
    # FIX-092: Contribution years account for arrival age (expats).
    # Swiss natives: from age 21. Expats: from arrival_age (if > 21).
    years_until_retirement = max(0, retirement_age - input.age)
    start_age = max(21, input.arrival_age or 21)
    current_contribution_years = max(0, min(input.age - start_age, AVS_DUREE_COTISATION_COMPLETE))
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
        retirement_age=retirement_age,
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
    archetype = _detect_archetype(input)
    has_lpp_for_3a = archetype != "independent_no_lpp"
    tax_saving_3a, marginal_tax_rate, _ = _estimate_3a_tax_impact(
        input.gross_salary,
        canton,
        has_lpp=has_lpp_for_3a,
        household_type=household_type,
    )

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
        archetype=archetype,
        disclaimer=_DISCLAIMER,
        sources=list(_SOURCES),
        enrichment_prompts=enrichment_prompts,
        age=input.age,
        gross_annual_salary=input.gross_salary,
        canton=canton,
    )
