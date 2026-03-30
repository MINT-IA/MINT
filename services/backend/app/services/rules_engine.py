"""
Mint Rules Engine
Generates recommendations based on user profile and session answers.
"""

import uuid
from datetime import datetime, timezone
from typing import List, Optional, Tuple

from app.constants.social_insurance import (
    LPP_TAUX_CONVERSION_MIN,
    MARRIED_CAPITAL_TAX_DISCOUNT,
    PILIER_3A_PLAFOND_AVEC_LPP,
    TAUX_IMPOT_RETRAIT_CAPITAL,
    calculate_progressive_capital_tax,
    get_ai_rente_monthly,
)

from app.schemas.common import Impact, Period
from app.schemas.recommendation import (
    Recommendation,
    NextAction,
    NextActionType,
    EvidenceLink,
)
from app.schemas.profile import Profile, Goal
from app.schemas.session import (
    SessionReport,
    ScoreboardItem,
    TopAction,
    GoalTemplate,
    SessionReportOverview,
    MintRoadmap,
    ConflictOfInterest,
)

# --- Swiss Legal Constants ---
MAX_RATE_CASH_CREDIT = 10.0
MAX_RATE_OVERDRAFT = 12.0

# --- Disability Gap Constants (CO art. 324a, LAI art. 28, LPP art. 23) ---
# Employer salary continuation scales by canton (weeks per year of service).
# Source: Jurisprudence TF — échelles bernoise, zurichoise, bâloise.
# All 26 cantons mapped to jurisprudence scales.
# Source: ATF + cantonal case law — Bern (majority), Zurich, Basel.
CANTON_SALARY_SCALE_MAP = {
    "AG": "bern",  "AI": "bern",  "AR": "bern",  "BE": "bern",
    "BL": "basel", "BS": "basel", "FR": "bern",  "GE": "bern",
    "GL": "bern",  "GR": "bern",  "JU": "bern",  "LU": "bern",
    "NE": "bern",  "NW": "bern",  "OW": "bern",  "SG": "bern",
    "SH": "bern",  "SO": "bern",  "SZ": "bern",  "TG": "bern",
    "TI": "bern",  "UR": "bern",  "VD": "bern",  "VS": "bern",
    "ZG": "bern",  "ZH": "zurich",
}

def _bern_scale_weeks(years: int) -> int:
    """Échelle bernoise (BE, VD, GE, LU). Source: ATF 4C.346/2005."""
    if years < 1:
        return 0
    if years == 1:
        return 3
    if years == 2:
        return 4
    if years <= 4:
        return 8
    if years <= 9:
        return 13
    if years <= 14:
        return 17
    if years <= 19:
        return 21
    return 26  # 20+


def _zurich_scale_weeks(years: int) -> int:
    """Échelle zurichoise (ZH). Source: Obergericht ZH."""
    if years < 1:
        return 0
    if years == 1:
        return 3
    if years == 2:
        return 8
    if years <= 4:
        return 8
    if years <= 9:
        return 13
    if years <= 14:
        return 17
    if years <= 19:
        return 21
    return 26  # 20+


def _basel_scale_weeks(years: int) -> int:
    """Échelle bâloise (BS, BL). Source: Basler Kommentar OR I."""
    if years < 1:
        return 0
    if years == 1:
        return 3
    if years <= 5:
        return 9
    if years <= 10:
        return 13
    if years <= 15:
        return 17
    if years <= 20:
        return 21
    return 26  # 21+


def get_employer_coverage_weeks(canton: str, years_of_service: int) -> int:
    """Return employer coverage duration in weeks for a given canton + seniority.

    Source: CO art. 324a + cantonal jurisprudence scales.
    """
    scale = CANTON_SALARY_SCALE_MAP.get(canton)
    if scale is None:
        raise ValueError(f"Canton non supporté: {canton}")
    if scale == "bern":
        return _bern_scale_weeks(years_of_service)
    elif scale == "zurich":
        return _zurich_scale_weeks(years_of_service)
    else:
        return _basel_scale_weeks(years_of_service)


def compute_disability_gap(
    monthly_income: float,
    employment_status: str,
    canton: str,
    years_of_service: int,
    has_ijm_collective: bool,
    disability_degree: int = 100,
    lpp_disability_benefit: float = 0.0,
) -> dict:
    """Compute 3-phase disability gap analysis.

    Phase 1: Employer salary continuation (CO art. 324a)
    Phase 2: IJM coverage (80% salary, up to 720 days)
    Phase 3: AI rente + LPP disability benefit

    Returns:
        dict with phase-by-phase coverage, gaps, risk level, and alerts.
    """
    if canton not in CANTON_SALARY_SCALE_MAP:
        raise ValueError(f"Canton non supporté: {canton}")

    alerts: List[str] = []

    # Phase 1: Employer coverage
    phase1_weeks = 0.0
    phase1_benefit = 0.0
    # FIX-162: Handle all employment statuses (was only employee/self_employed).
    # Normalize FR → EN aliases
    _status = employment_status.lower().strip()
    if _status in ("salarie", "employee"):
        _status = "employee"
    elif _status in ("independant", "self_employed"):
        _status = "self_employed"
    elif _status in ("retraite", "retired"):
        _status = "retired"

    if _status == "employee":
        phase1_weeks = float(get_employer_coverage_weeks(canton, years_of_service))
        phase1_benefit = monthly_income  # 100% salary
    elif _status == "retired":
        # Retirees already covered by AI rente — no employer phase
        alerts.append("Retraité·e : couvert·e par l'AI/AVS. L'invalidité s'applique différemment.")
    elif _status == "student":
        alerts.append("Étudiant·e : aucune couverture employeur ni IJM. Vérifier l'assurance accidents (LAA).")
    elif _status == "unemployed":
        alerts.append("Sans emploi : couverture via l'assurance-chômage (LACI art. 22). Vérifier la durée restante.")
    else:
        alerts.append("Indépendant·e : aucune couverture employeur")
    phase1_gap = monthly_income - phase1_benefit

    # Phase 2: IJM
    phase2_duration_months = 24.0
    phase2_benefit = 0.0
    if (_status in ("employee", "self_employed") and has_ijm_collective):
        phase2_benefit = monthly_income * 0.8
    else:
        alerts.append("Aucune IJM: après la période employeur, plus rien jusqu'à l'AI")
    phase2_gap = monthly_income - phase2_benefit

    # Phase 3: AI + LPP
    ai_rente = get_ai_rente_monthly(disability_degree)
    phase3_benefit = ai_rente + lpp_disability_benefit
    phase3_gap = monthly_income - phase3_benefit

    # Risk level
    if _status == "self_employed" and not has_ijm_collective:
        risk_level = "critical"
        alerts.append("CRITIQUE: Indépendant sans IJM = aucune couverture pendant 24 mois")
    elif _status == "retired":
        risk_level = "low"  # Already covered by AI/AVS
    elif _status in ("student", "unemployed"):
        risk_level = "high"
    elif _status == "employee" and not has_ijm_collective:
        risk_level = "high"
        alerts.append(f"HAUT RISQUE: Après {int(phase1_weeks)} semaines, plus rien")
    elif phase3_gap > 3000:
        risk_level = "medium"
        alerts.append("Gap important à long terme (AI + LPP insuffisants)")
    else:
        risk_level = "low"

    return {
        "revenu_actuel": monthly_income,
        "phase1_duration_weeks": phase1_weeks,
        "phase1_monthly_benefit": phase1_benefit,
        "phase1_gap": phase1_gap,
        "phase2_duration_months": phase2_duration_months,
        "phase2_monthly_benefit": phase2_benefit,
        "phase2_gap": phase2_gap,
        "phase3_monthly_benefit": phase3_benefit,
        "phase3_gap": phase3_gap,
        "risk_level": risk_level,
        "alerts": alerts,
        "ai_rente_mensuelle": ai_rente,
        "lpp_disability_benefit": lpp_disability_benefit,
    }


# --- Goal Templates (Canonical) ---
GOAL_TEMPLATES = {
    "goal_control_debts": "Reprendre le contrôle (budget + dettes)",
    "goal_emergency_fund": "Construire un fonds d'urgence",
    "goal_tax_basic": "Payer moins d'impôts (3a + bases)",
    "goal_house": "Préparer un achat logement",
    "goal_pension_opt": "Optimiser ma prévoyance (LPP/3a)",
    "goal_invest_simple": "Investir simplement (après les bases)",
    "goal_retirement_plan": "Préparer la retraite (plan clair)",
}

# --- Pure Financial Calculations ---


def calculate_precision_score(profile: Profile, answers: dict) -> float:
    """Calculate FactFind completeness index."""
    fields = [
        profile.birthYear,
        profile.canton,
        profile.incomeNetMonthly,
        profile.savingsMonthly,
        profile.incomeGrossYearly,
        profile.lppInsuredSalary,
        answers.get("hasDebt"),
        answers.get("housingType"),
    ]
    filled = len([f for f in fields if f is not None])
    return round(filled / len(fields), 2)


def calculate_compound_interest(
    principal: float, monthly_contribution: float, annual_rate: float, years: int
) -> dict:
    r = annual_rate / 100 / 12
    n = years * 12
    if r == 0:
        final_value = principal + monthly_contribution * n
    else:
        fv_principal = principal * ((1 + r) ** n)
        fv_annuity = monthly_contribution * (((1 + r) ** n - 1) / r)
        final_value = fv_principal + fv_annuity
    total_invested = principal + monthly_contribution * n
    gains = final_value - total_invested
    return {
        "finalValue": round(final_value, 2),
        "totalInvested": round(total_invested, 2),
        "gains": round(gains, 2),
    }


def calculate_pillar3a_tax_benefit(
    annual_contribution: float,
    marginal_tax_rate: float,
    years: int,
    annual_return: float = 4.0,
) -> dict:
    annual_tax_saved = annual_contribution * marginal_tax_rate
    compound = calculate_compound_interest(
        principal=0,
        monthly_contribution=annual_contribution / 12,
        annual_rate=annual_return,
        years=years,
    )
    return {
        "annualTaxSaved": round(annual_tax_saved, 2),
        "totalTaxSavedOverPeriod": round(annual_tax_saved * years, 2),
        "potentialFinalValue": compound["finalValue"],
        "totalContributions": round(annual_contribution * years, 2),
    }


def calculate_leasing_opportunity_cost(
    monthly_payment: float, duration_months: int, alternative_annual_rate: float
) -> dict:
    """Calculate what the leasing money could have earned if invested."""
    total_cost = monthly_payment * duration_months

    def calc_horizon(years):
        return calculate_compound_interest(
            0, monthly_payment, alternative_annual_rate, years
        )["gains"]

    return {
        "totalLeasingCost": round(total_cost, 2),
        "opportunityCost": {
            "5y": round(calc_horizon(5), 2),
            "10y": round(calc_horizon(10), 2),
            "20y": round(calc_horizon(20), 2),
        },
        "potentialTotalWealth": round(calc_horizon(duration_months / 12), 2),
    }


# --- IFD Brackets (LIFD art. 36, 2024) ---
# Format: list of (cumulative_threshold_CHF, marginal_rate_percent)

IFD_BRACKETS_SINGLE = [
    (14500, 0.0), (31600, 0.77), (41400, 0.88), (55200, 2.64),
    (72500, 2.97), (78100, 5.94), (103600, 6.60), (134600, 8.80),
    (176000, 11.00), (755200, 13.20), (float("inf"), 11.50),
]

IFD_BRACKETS_MARRIED = [
    (28300, 0.0), (50900, 1.0), (58400, 2.0), (75300, 3.0),
    (90300, 4.0), (103400, 5.0), (114700, 6.0), (124200, 7.0),
    (131700, 8.0), (137300, 9.0), (141200, 10.0), (143100, 11.0),
    (145000, 12.0), (895900, 13.0), (float("inf"), 11.50),
]

# Estimated cantonal+communal marginal add-on by canton.
# These approximate the additional cantonal/communal marginal rate on top of IFD.
# Source: swiss-brain estimates based on chef-lieu rates, 2024.
# All 26 cantons — estimated cantonal+communal marginal add-on (chef-lieu, 2024).
CANTON_MARGINAL_MULTIPLIERS = {
    "AG": 0.31, "AI": 0.26, "AR": 0.28, "BE": 0.36,
    "BL": 0.32, "BS": 0.33, "FR": 0.37, "GE": 0.41,
    "GL": 0.28, "GR": 0.29, "JU": 0.40, "LU": 0.25,
    "NE": 0.39, "NW": 0.24, "OW": 0.24, "SG": 0.30,
    "SH": 0.30, "SO": 0.32, "SZ": 0.24, "TG": 0.29,
    "TI": 0.33, "UR": 0.26, "VD": 0.38, "VS": 0.34,
    "ZG": 0.22, "ZH": 0.30,
}

_DEFAULT_CANTON_MULTIPLIER = 0.32  # Moyenne CH


def _get_ifd_marginal_rate(income_gross: float, household_type: str) -> float:
    """Return the IFD marginal rate (as decimal, e.g. 0.066) for the last bracket reached.

    Barèmes LIFD art. 36 al. 1 (célibataires) et al. 2 (mariés), 2024.
    """
    brackets = (
        IFD_BRACKETS_MARRIED if household_type == "married" else IFD_BRACKETS_SINGLE
    )
    previous = 0.0
    marginal_rate_pct = 0.0
    for threshold, rate_pct in brackets:
        if income_gross <= previous:
            break
        marginal_rate_pct = rate_pct
        previous = threshold
    return marginal_rate_pct / 100


def calculate_marginal_tax_rate(
    canton: str, income_gross: float, household_type: str = "single"
) -> float:
    """Estimate combined marginal tax rate (IFD + cantonal/communal).

    The marginal rate is the rate applied to the last franc earned.
    Result is clamped between 0.10 and 0.45.

    Args:
        canton: Canton code (e.g. "ZH", "GE", "VD").
        income_gross: Annual gross income in CHF.
        household_type: "single" or "married".

    Returns:
        Combined marginal tax rate as a decimal (e.g. 0.35 for 35%).

    Sources:
        - IFD: LIFD art. 36 (2024)
        - Cantonal: swiss-brain estimates based on chef-lieu rates
    """
    ifd_marginal = _get_ifd_marginal_rate(income_gross, household_type)
    canton_addon = CANTON_MARGINAL_MULTIPLIERS.get(canton, _DEFAULT_CANTON_MULTIPLIER)
    combined = ifd_marginal + canton_addon
    return max(0.10, min(0.45, round(combined, 4)))


def calculate_tax_potential(
    canton: str, income_gross: float, household_type: str = "single"
) -> str:
    """Estimate potential tax savings (3a only) for MVP display."""
    # Logic: 3a Max (7258) * Marginal Rate
    marginal_rate = calculate_marginal_tax_rate(canton, income_gross, household_type)
    saving = PILIER_3A_PLAFOND_AVEC_LPP * marginal_rate
    # Format as range "~1100-1400" to be safe/realistic relative to user expectation
    low = int(saving * 0.9 / 100) * 100
    high = int(saving * 1.1 / 100) * 100
    return f"~{low}-{high} CHF"


def _simulate_capital_drawdown(
    capital_net: float,
    retrait_mensuel: float,
    rendement_annuel: float,
    nb_mois: int,
) -> Tuple[float, Optional[int]]:
    """Simulate month-by-month capital drawdown with returns.

    Args:
        capital_net: Starting capital after withdrawal tax (CHF).
        retrait_mensuel: Monthly withdrawal amount (CHF).
        rendement_annuel: Annual net return as decimal (e.g. 0.03 for 3%).
        nb_mois: Number of months to simulate.

    Returns:
        Tuple of (capital at end of period, month index when capital <= 0 or None).
    """
    rendement_mensuel = rendement_annuel / 12
    capital = capital_net
    break_even_mois: Optional[int] = None

    for mois in range(1, nb_mois + 1):
        capital = capital * (1 + rendement_mensuel) - retrait_mensuel
        if capital <= 0 and break_even_mois is None:
            break_even_mois = mois
            capital = 0.0

    return (capital, break_even_mois)


def compute_rente_vs_capital(
    avoir_obligatoire: float,
    avoir_surobligatoire: float,
    taux_conversion_surob: float,
    age_retraite: int,
    canton: str,
    statut_civil: str,
) -> dict:
    """Compare rente viagère LPP vs retrait en capital sur 3 scénarios.

    Source: LPP art. 14 al. 2 (taux conversion 6.8%), LIFD art. 38 (imposition capital).
    Supports all 26 Swiss cantons with progressive tax brackets.

    Args:
        avoir_obligatoire: LPP mandatory assets (CHF).
        avoir_surobligatoire: LPP supra-mandatory assets (CHF).
        taux_conversion_surob: Supra-mandatory conversion rate as decimal (e.g. 0.05).
        age_retraite: Retirement age (55-70).
        canton: Canton code (all 26 Swiss cantons).
        statut_civil: "single" or "married".

    Returns:
        dict with rente_annuelle, capital_total, impot_retrait, capital_net,
        and 3 scenario simulations up to age 85.
    """
    rente_annuelle = avoir_obligatoire * (LPP_TAUX_CONVERSION_MIN / 100) + avoir_surobligatoire * taux_conversion_surob
    rente_mensuelle = rente_annuelle / 12

    capital_total = avoir_obligatoire + avoir_surobligatoire

    base_rate = TAUX_IMPOT_RETRAIT_CAPITAL.get(canton)
    if base_rate is None:
        raise ValueError(f"Canton non supporté: {canton}")

    effective_rate = base_rate * MARRIED_CAPITAL_TAX_DISCOUNT if statut_civil == "married" else base_rate
    impot_retrait = calculate_progressive_capital_tax(capital_total, effective_rate)
    capital_net = capital_total - impot_retrait

    nb_mois_85 = (85 - age_retraite) * 12
    nb_mois_max = (150 - age_retraite) * 12

    scenarios = {}
    for nom, rendement in [("prudent", 0.01), ("central", 0.03), ("optimiste", 0.05)]:
        capital_final_85, _ = _simulate_capital_drawdown(
            capital_net, rente_mensuelle, rendement, nb_mois_85,
        )
        _, break_even_mois = _simulate_capital_drawdown(
            capital_net, rente_mensuelle, rendement, nb_mois_max,
        )

        capital_85 = max(0.0, round(capital_final_85, 2))
        break_even_age: Optional[float] = None
        if break_even_mois is not None:
            break_even_age = round(age_retraite + break_even_mois / 12, 1)

        scenarios[nom] = {
            "rendement": rendement,
            "capital_85": capital_85,
            "break_even_age": break_even_age,
        }

    return {
        "rente_annuelle": round(rente_annuelle, 2),
        "rente_mensuelle": round(rente_mensuelle, 2),
        "capital_total": round(capital_total, 2),
        "impot_retrait": round(impot_retrait, 2),
        "capital_net": round(capital_net, 2),
        "scenarios": scenarios,
    }


def calculate_consumer_credit(
    amount: float, duration_months: int, annual_rate: float, fees: float = 0
) -> dict:
    if duration_months <= 0:
        return {"error": "Invalid duration"}

    r = annual_rate / 100 / 12
    if r == 0:
        monthly_payment = amount / duration_months
    else:
        monthly_payment = amount * r / (1 - (1 + r) ** -duration_months)

    total_payment = monthly_payment * duration_months
    total_cost = total_payment + fees
    total_interest = total_payment - amount

    rate_warning = annual_rate >= MAX_RATE_CASH_CREDIT

    return {
        "monthlyPayment": round(monthly_payment, 2),
        "totalInterest": round(total_interest, 2),
        "totalCost": round(total_cost, 2),
        "rateWarning": rate_warning,
        "legalMaxRate": MAX_RATE_CASH_CREDIT if rate_warning else None,
    }


def calculate_debt_risk_score(
    has_regular_overdrafts: bool,
    has_multiple_credits: bool,
    has_late_payments: bool,
    has_debt_collection: bool,
    has_impulsive_buying: bool,
    has_gambling_habit: bool,
) -> dict:
    factors = [
        has_regular_overdrafts,
        has_multiple_credits,
        has_late_payments,
        has_debt_collection,
        has_impulsive_buying,
        has_gambling_habit,
    ]
    score = sum(1 for f in factors if f)

    if score >= 4:
        level = "high"
    elif score >= 2:
        level = "medium"
    else:
        level = "low"

    recos = []
    if level == "high":
        recos.append("Consulter un service de désendettement (Caritas/Dettes.ch)")
    if level == "medium":
        recos.append("Faire un budget strict")
    else:
        recos.append("Maintenir les bonnes habitudes")

    if has_gambling_habit:
        recos.append("Jeu excessif: consulter SOS Jeu")

    return {
        "riskScore": score,
        "riskLevel": level,
        "recommendations": recos,
        "hasGamblingRisk": has_gambling_habit,
    }


# --- Orchestration ---


def recommend_goal_template(profile: Profile, answers: dict) -> Tuple[str, List[str]]:
    if answers.get("hasDebt") or profile.hasDebt:
        recommended = "goal_control_debts"
        alternatives = ["goal_emergency_fund", "goal_tax_basic"]
    elif profile.goal == Goal.house:
        recommended = "goal_house"
        alternatives = ["goal_tax_basic", "goal_pension_opt"]
    elif profile.goal == Goal.retire:
        recommended = "goal_retirement_plan"
        alternatives = ["goal_pension_opt", "goal_invest_simple"]
    else:
        recommended = "goal_emergency_fund"
        alternatives = ["goal_tax_basic", "goal_invest_simple"]
    return recommended, alternatives


def select_focus_kinds(profile: Profile, answers: dict) -> List[str]:
    priorities = []
    if answers.get("hasDebt") or profile.hasDebt:
        priorities += ["debt_risk", "consumer_credit"]
    if profile.goal in [Goal.optimize_taxes, Goal.retire]:
        priorities.append("pillar3a")

    defaults = ["pillar3a", "compound_interest", "leasing", "debt_risk"]
    for d in defaults:
        if d not in priorities:
            priorities.append(d)
    return priorities[:3]


def generate_if_then(kind: str, profile: Profile, answers: dict) -> str:
    if kind == "pillar3a":
        return "SI je verse 605 CHF/mois, ALORS j'économise environ 1500 CHF d'impôts par an."
    if kind == "compound_interest":
        return f"SI je commence à épargner {profile.savingsMonthly or 500} CHF aujourd'hui, ALORS mon capital doublera en 14 ans (à 5%)."
    if kind == "debt_risk":
        return "SI je fais mon budget ce soir, ALORS je réduis mon stress financier de 50% sous 30 jours."
    return "SI je réalise cette action, ALORS j'améliore ma situation durablement."


# --- Recommendations ---


def generate_recommendations(
    profile: Profile, answers: dict = None, reference_date: Optional[datetime] = None
) -> List[Recommendation]:
    """
    Génère des recommandations triées par pertinence (Score d'impact).
    """
    from app.schemas.profile import HouseholdType
    
    answers = answers or {}
    potential_recos = []
    
    # 1. Protection & Dettes (Priorité 1)
    if profile.hasDebt or answers.get("q_has_consumer_debt") == "yes":
        potential_recos.append(_create_debt_repayment_recommendation(profile))
    else:
        potential_recos.append(_create_debt_risk_recommendation(profile))

    # 2. Budget (Priorité 2 si épargne faible)
    savings = profile.savingsMonthly or 0
    if savings < 200:
        potential_recos.append(_create_budget_control_recommendation(profile))

    # 3. Prévoyance (Priorité 1-2 si revenus corrects)
    estimated_net = profile.incomeNetMonthly or (
        (profile.incomeGrossYearly / 12 * 0.85) if profile.incomeGrossYearly else 0
    )
    if estimated_net > 3000:
        potential_recos.append(_create_3a_optimizer_recommendation(profile, reference_date=reference_date))
        if profile.employmentStatus == "self_employed":
            potential_recos.append(_create_pension_3a_self_employed_recommendation(profile))

    # 4. Investissement (Priorité 3)
    if savings > 500:
        potential_recos.append(_create_compound_interest_recommendation(profile))

    # 5. Cas Spéciaux
    if profile.householdType == HouseholdType.concubine:
        potential_recos.append(_create_legal_protection_recommendation(profile))
    
    if profile.householdType == HouseholdType.family and profile.incomeNetMonthly and profile.incomeNetMonthly > 10000:
        potential_recos.append(_create_tax_splitting_recommendation(profile))

    # Tri par importance théorique (MVP: simple liste ordonnée)
    return potential_recos


def _create_3a_optimizer_recommendation(
    profile: Profile, reference_date: Optional[datetime] = None
) -> Recommendation:
    annual_contribution = PILIER_3A_PLAFOND_AVEC_LPP
    household_type = "married" if profile.householdType.value in ("couple", "family") else "single"
    marginal_rate = calculate_marginal_tax_rate(
        profile.canton or "ZH",
        profile.incomeGrossYearly or (profile.incomeNetMonthly or 5000) * 12 / 0.85,
        household_type,
    )
    now = reference_date or datetime.now(timezone.utc)
    years = max(5, 65 - (now.year - (profile.birthYear or 1990)))
    calc = calculate_pillar3a_tax_benefit(annual_contribution, marginal_rate, years)
    return Recommendation(
        id=uuid.uuid4(),
        kind="pillar3a",
        title="Optimiser votre 3e pilier",
        summary=f"Économisez CHF {calc['annualTaxSaved']:,.0f}/an d'impôts.",
        why=["Déduction fiscale immédiate."],
        assumptions=[f"Contribution max: CHF {annual_contribution}"],
        impact=Impact(amountCHF=calc["annualTaxSaved"], period=Period.yearly),
        risks=["Capital bloqué."],
        alternatives=["Compte épargne"],
        evidenceLinks=[
            EvidenceLink(
                label="Calculateur impôts (Admin)",
                url="https://www.estv.admin.ch/estv/fr/home/impots-federaux/impot-anticipe/impot-anticipe/calculateurs.html",
            ),
            EvidenceLink(
                label="Le fonctionnement du 3a",
                url="https://www.ch.ch/fr/retraite/le-3e-pilier-prive/",
            ),
        ],
        nextActions=[
            NextAction(
                type=NextActionType.partner_handoff,
                label="Comparer les offres",
                partnerId="partner-3a-1",
            )
        ],
    )


def _create_compound_interest_recommendation(profile: Profile) -> Recommendation:
    profile.savingsMonthly or 500.0  # Used effectively in default logic implicitly or just for validation
    return Recommendation(
        id=uuid.uuid4(),
        kind="compound_interest",
        title="Intérêts Composés",
        summary="Le temps est un allié puissant.",
        why=["Effet boule de neige."],
        assumptions=["Rendement annuel 5%."],
        impact=Impact(amountCHF=5000, period=Period.oneoff),
        risks=["Marché fluctuant."],
        alternatives=["Immobilier"],
        evidenceLinks=[
            EvidenceLink(
                label="Comprendre les intérêts",
                url="https://www.rts.ch/decouverte/sciences-et-environnement/math-et-informatique/le-monde-des-chiffres/4580220-les-interets-composes-ou-leffet-boule-de-neige.html",
            )
        ],
        nextActions=[
            NextAction(type=NextActionType.simulate, label="Simuler mes gains")
        ],
    )


def _create_debt_risk_recommendation(profile: Profile) -> Recommendation:
    return Recommendation(
        id=uuid.uuid4(),
        kind="debt_risk",
        title="Check-up Prévention",
        summary="Évaluez votre risque de surendettement.",
        why=["La clarté réduit le stress."],
        assumptions=["Données anonymes."],
        impact=Impact(amountCHF=0, period=Period.oneoff),
        risks=["Déni de situation."],
        alternatives=["Conseil local gratuit"],
        evidenceLinks=[
            EvidenceLink(label="Où demander de l'aide ?", url="https://www.dettes.ch/"),
            EvidenceLink(
                label="Service de désendettement (Caritas)",
                url="https://www.caritas.ch/fr/notre-engagement-en-suisse/conseil-en-matiere-de-dettes",
            ),
        ],
        nextActions=[
            NextAction(type=NextActionType.simulate, label="Faire le check-up")
        ],
    )


def _create_legal_protection_recommendation(profile: Profile) -> Recommendation:
    return Recommendation(
        id=uuid.uuid4(),
        kind="legal_protection",
        title="Protéger mon conjoint",
        summary="Le concubinage n'offre aucune protection légale.",
        why=["En cas de décès, le partenaire ne reçoit rien."],
        assumptions=["Pas de testament existant."],
        impact=Impact(amountCHF=0, period=Period.oneoff),
        risks=["Risque de tout perdre."],
        alternatives=["Mariage", "Pacs (Geneve)"],
        evidenceLinks=[
            EvidenceLink(
                label="Comprendre les risques",
                url="https://www.ch.ch/fr/famille-et-partenariat/concubinage/",
            ),
        ],
        nextActions=[
            NextAction(type=NextActionType.learn, label="Lire le guide héritage")
        ],
    )


def _create_debt_repayment_recommendation(profile: Profile) -> Recommendation:
    return Recommendation(
        id=uuid.uuid4(),
        kind="debt_repayment",
        title="Remboursement Accéléré",
        summary="Priorité absolue : éliminer vos dettes à taux élevé.",
        why=["Le coût des dettes est supérieur à n'importe quel placement.", "Libère de la capacité d'épargne mensuelle."],
        assumptions=["Taux moyen estimé à 10%.", "Remboursement mensuel cible: 10% du revenu."],
        risks=["Manque de liquidités immédiates.", "Rigidité budgétaire possible."],
        alternatives=["Consolidation de crédit", "Rachat de crédit"],
        impact=Impact(amountCHF=1200, period=Period.yearly),
        nextActions=[
            NextAction(type=NextActionType.simulate, label="Optimiser mon remboursement")
        ],
    )


def _create_budget_control_recommendation(profile: Profile) -> Recommendation:
    return Recommendation(
        id=uuid.uuid4(),
        kind="budget_control",
        title="Reprendre le contrôle",
        summary="Stabilisez votre budget pour créer une capacité d'épargne.",
        why=["Sans épargne, pas d'investissement possible.", "Réduit l'anxiété financière."],
        assumptions=["Revenus fixes.", "Dépenses incompressibles identifiées."],
        risks=["Effort de discipline initial.", "Modification du train de vie."],
        alternatives=["Application de gestion tiers", "Journal papier"],
        impact=Impact(amountCHF=2400, period=Period.yearly),
        nextActions=[
            NextAction(type=NextActionType.simulate, label="Faire mon budget")
        ],
    )


def _create_pension_3a_self_employed_recommendation(profile: Profile) -> Recommendation:
    return Recommendation(
        id=uuid.uuid4(),
        kind="pension_3a",
        title="3e Pilier Indépendant",
        summary="Versez jusqu'à 20% de votre revenu (max CHF 36'288).",
        why=["Bonus fiscal massif pour les indépendants sans LPP.", "Liberté de choix de l'institut."],
        assumptions=["Revenu annuel net > 30k CHF.", "Pas d'affiliation LPP."],
        risks=["Capital bloqué jusqu'à 5 ans avant l'âge de la retraite.", "Dépendance au revenu net variable."],
        alternatives=["Placement libre", "Rachat LPP si affilié"],
        impact=Impact(amountCHF=8500, period=Period.yearly),
        nextActions=[
            NextAction(type=NextActionType.partner_handoff, label="Ouvrir un 3a Indépendant", partnerId="partner-3a-self")
        ],
    )


def _create_tax_splitting_recommendation(profile: Profile) -> Recommendation:
    return Recommendation(
        id=uuid.uuid4(),
        kind="tax_optimization",
        title="Optimisation du Splitting",
        summary="Optimisez la répartition des revenus du ménage.",
        why=["Le barème marié peut être optimisé par le 3a et les déductions enfants.", "Réduction de la progressivité de l'impôt."],
        assumptions=["Revenu du ménage > 120'000 CHF.", "Canton avec barèmes progressifs."],
        risks=["Complexité administrative.", "Modification des acomptes provisionnels."],
        alternatives=["Changement de canton", "Dons caritatifs"],
        impact=Impact(amountCHF=3500, period=Period.yearly),
        nextActions=[
            NextAction(type=NextActionType.learn, label="Comprendre l'impôt marié")
        ],
    )


# --- Full Report Generation ---


def generate_session_report(
    profile: Profile, answers: dict, focus_kinds: List[str], session_id: uuid.UUID,
    reference_date: Optional[datetime] = None,
) -> SessionReport:
    precision = calculate_precision_score(profile, answers)
    now = reference_date or datetime.now(timezone.utc)
    all_recos = generate_recommendations(profile, answers, reference_date=now)

    # Identify Top 3
    priority_map = {
        "debt_repayment": 0,
        "debt_risk": 1,
        "budget_control": 2,
        "pension_3a": 3,
        "pillar3a": 4,
        "tax_optimization": 5,
        "legal_protection": 6,
        "compound_interest": 7
    }
    sorted_recos = sorted(all_recos, key=lambda r: priority_map.get(r.kind, 99))
    top_recos = sorted_recos[:3]

    # Ensure at least 3 recommendations for topActions
    while len(top_recos) < 3:
        fallback = Recommendation(
            id=uuid.uuid4(),
            kind="general",
            title="Faire le point",
            summary="Complétez votre profil pour des recommandations plus précises.",
            why=["Plus de données = plan plus précis."],
            assumptions=["Profil incomplet."],
            impact=Impact(amountCHF=0, period=Period.oneoff),
            risks=[],
            alternatives=[],
            nextActions=[
                NextAction(type=NextActionType.learn, label="Compléter mon profil")
            ],
        )
        top_recos.append(fallback)

    top_actions = []
    for r in top_recos:
        top_actions.append(
            TopAction(
                effortTag="30 min",
                label=r.title,
                why=r.summary,
                ifThen=generate_if_then(r.kind, profile, answers),
                nextAction=r.nextActions[0],
            )
        )

    recommended_id, alternatives_ids = recommend_goal_template(profile, answers)
    recommended_goal = GoalTemplate(
        id=recommended_id, label=GOAL_TEMPLATES[recommended_id]
    )
    alternatives = [
        GoalTemplate(id=gid, label=GOAL_TEMPLATES[gid]) for gid in alternatives_ids
    ]

    # Roadmap Logic (Safe Terminology)
    roadmap = MintRoadmap(
        mentorshipLevel="Guidance Générale (MVP)",
        natureOfService="Coaching / Mentorat Informatif",
        limitations=[
            "Basé sur des déclarations auto-remplies sans vérification.",
            "Ne constitue pas un conseil en investissement personnalisé au sens de la LSFin.",
        ],
        assumptions=[
            f"Taux marginal estimé à {int(calculate_marginal_tax_rate(profile.canton or 'ZH', profile.incomeGrossYearly or 80000) * 100)}% ({profile.canton or 'CH'}).",
            "Profil de risque modéré par défaut.",
        ],
        conflictsOfInterest=[
            ConflictOfInterest(
                partner="Partner-3a-1",
                type="Commission",
                disclosure="Mint perçoit CHF 50 par ouverture de compte.",
            )
        ],
    )

    return SessionReport(
        id=uuid.uuid4(),
        sessionId=session_id,
        precisionScore=precision,
        title="Bilan & Plan d'actions Mint",
        overview=SessionReportOverview(
            canton=profile.canton or "Suisse",
            householdType=profile.householdType.value,
            goalRecommendedLabel=recommended_goal.label,
        ),
        mintRoadmap=roadmap,
        scoreboard=[
            ScoreboardItem(
                label="Précision Index",
                value=f"{int(precision * 100)}%",
                note="Utility-based score",
            ),
            ScoreboardItem(
                label="Épargne/Impôts",
                value=calculate_tax_potential(
                    profile.canton, profile.incomeGrossYearly or 80000
                ),
                note="Basé sur votre canton",
            ),
            ScoreboardItem(
                label="Mode Santé",
                value="Safe" if not profile.hasDebt else "Point d'attention",
                note="Prévention active",
            ),
            ScoreboardItem(
                label="Horizon", value="Long Terme", note="Investissement suggéré"
            ),
        ],
        recommendedGoalTemplate=recommended_goal,
        alternativeGoalTemplates=alternatives,
        topActions=top_actions,
        recommendations=all_recos,
        disclaimers=[
            "Ceci n'est pas un diagnostic définitif.",
            "Mint est un mentor, pas un gestionnaire de fortune.",
            "Données traitées en Suisse (Blink/Mint).",
        ],
        generatedAt=now,
    )
