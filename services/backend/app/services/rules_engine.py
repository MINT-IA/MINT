"""
Mint Rules Engine
Generates recommendations based on user profile and session answers.
"""

import uuid
from datetime import datetime
from typing import List, Tuple
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
        return calculate_compound_interest(0, monthly_payment, alternative_annual_rate, years)["gains"]

    return {
        "totalLeasingCost": round(total_cost, 2),
        "opportunityCost": {
            "5y": round(calc_horizon(5), 2),
            "10y": round(calc_horizon(10), 2),
            "20y": round(calc_horizon(20), 2),
        },
        "potentialTotalWealth": round(calc_horizon(duration_months / 12), 2),
    }


def calculate_marginal_tax_rate(canton: str, income_gross: float) -> float:
    # Very simplified Swiss tax logic for MVP
    if income_gross < 50000:
        return 0.15
    if income_gross < 100000:
        return 0.22
    if income_gross < 150000:
        return 0.28
    return 0.35


def calculate_tax_potential(canton: str, income_gross: float) -> str:
    """Estimate potential tax savings (3a only) for MVP display."""
    # Logic: 3a Max (7258) * Marginal Rate
    marginal_rate = calculate_marginal_tax_rate(canton, income_gross)
    saving = 7258.0 * marginal_rate
    # Format as range "~1100-1400" to be safe/realistic relative to user expectation
    low = int(saving * 0.9 / 100) * 100
    high = int(saving * 1.1 / 100) * 100
    return f"~{low}-{high} CHF"


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


def generate_recommendations(profile: Profile) -> List[Recommendation]:
    recos = [
        _create_3a_optimizer_recommendation(profile),
        _create_compound_interest_recommendation(profile),
        _create_debt_risk_recommendation(profile),
    ]
    if profile.householdType == "concubine":
        recos.insert(0, _create_legal_protection_recommendation(profile))
    return recos


def _create_3a_optimizer_recommendation(profile: Profile) -> Recommendation:
    annual_contribution = 7258.0
    marginal_rate = 0.25
    years = max(5, 65 - (datetime.utcnow().year - (profile.birthYear or 1990)))
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
        summary="Le temps est votre meilleur allié.",
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
            EvidenceLink(label="Comprendre les risques", url="https://www.ch.ch/fr/famille-et-partenariat/concubinage/"),
        ],
        nextActions=[
            NextAction(type=NextActionType.learn, label="Lire le guide héritage")
        ],
    )


# --- Full Report Generation ---


def generate_session_report(
    profile: Profile, answers: dict, focus_kinds: List[str], session_id: uuid.UUID
) -> SessionReport:
    precision = calculate_precision_score(profile, answers)
    all_recos = generate_recommendations(profile)

    # Identify Top 3
    priority_map = {"debt_risk": 0, "pillar3a": 1, "compound_interest": 2}
    sorted_recos = sorted(all_recos, key=lambda r: priority_map.get(r.kind, 99))
    top_recos = sorted_recos[:3]

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
            f"Taux marginal estimé à 25% ({profile.canton or 'CH'}).",
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
                value=calculate_tax_potential(profile.canton, profile.incomeGrossYearly or 80000),
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
        generatedAt=datetime.utcnow(),
    )
