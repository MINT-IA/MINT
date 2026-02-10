"""
Retirement planning endpoints — Sprint S21.

POST /api/v1/retirement/avs/estimate  — Estimate AVS pension
POST /api/v1/retirement/lpp/compare   — Compare LPP rente vs capital
POST /api/v1/retirement/budget        — Retirement budget reconciliation
GET  /api/v1/retirement/checklist     — Retirement preparation checklist

All endpoints are stateless (no data storage). Pure computation on the fly.
"""

from fastapi import APIRouter

from app.schemas.retirement import (
    AvsEstimationRequest,
    AvsEstimationResponse,
    LppConversionRequest,
    LppConversionResponse,
    RetirementBudgetRequest,
    RetirementBudgetResponse,
)
from app.services.retirement.avs_estimation_service import AvsEstimationService
from app.services.retirement.lpp_conversion_service import LppConversionService
from app.services.retirement.retirement_budget_service import RetirementBudgetService


router = APIRouter()

DISCLAIMER = (
    "Estimations educatives simplifiees. Ne constitue pas un conseil "
    "en prevoyance (LSFin). Consulte un ou une specialiste."
)


# ---------------------------------------------------------------------------
# AVS Estimation
# ---------------------------------------------------------------------------

@router.post("/avs/estimate", response_model=AvsEstimationResponse)
def estimate_avs(request: AvsEstimationRequest) -> AvsEstimationResponse:
    """Estimate AVS first-pillar pension under different scenarios.

    Scenarios: anticipation (63-64), normal (65), ajournement (66-70).
    Accounts for contribution gaps and couple plafonnement.

    Sources: LAVS art. 21bis, 21ter, 29.
    """
    service = AvsEstimationService()
    result = service.estimate(
        current_age=request.age_actuel,
        retirement_age=request.age_retraite,
        is_couple=request.is_couple,
        annees_lacunes=request.annees_lacunes,
        life_expectancy=request.esperance_vie,
    )
    return AvsEstimationResponse(
        scenario=result.scenario,
        age_depart=result.age_depart,
        rente_mensuelle=result.rente_mensuelle,
        rente_annuelle=result.rente_annuelle,
        facteur_ajustement=result.facteur_ajustement,
        penalite_ou_bonus_pct=result.penalite_ou_bonus_pct,
        rente_couple_mensuelle=result.rente_couple_mensuelle,
        duree_estimee_ans=result.duree_estimee_ans,
        total_cumule=result.total_cumule,
        breakeven_vs_normal=result.breakeven_vs_normal,
        chiffre_choc=result.chiffre_choc,
        disclaimer=DISCLAIMER,
        sources=result.sources,
    )


# ---------------------------------------------------------------------------
# LPP Conversion (Rente vs Capital)
# ---------------------------------------------------------------------------

@router.post("/lpp/compare", response_model=LppConversionResponse)
def compare_lpp(request: LppConversionRequest) -> LppConversionResponse:
    """Compare LPP rente vs capital withdrawal at retirement.

    Includes breakeven age, progressive capital tax, and neutral recommendation.

    Sources: LPP art. 14, LIFD art. 38.
    """
    service = LppConversionService()
    result = service.compare(
        capital_lpp=request.capital_lpp,
        canton=request.canton,
        retirement_age=request.age_retraite,
        life_expectancy=request.esperance_vie,
    )
    return LppConversionResponse(
        capital_total=result.capital_total,
        option_rente_mensuelle=result.option_rente_mensuelle,
        option_rente_annuelle=result.option_rente_annuelle,
        option_capital_brut=result.option_capital_brut,
        option_capital_impot=result.option_capital_impot,
        option_capital_net=result.option_capital_net,
        breakeven_age=result.breakeven_age,
        recommandation_neutre=result.recommandation_neutre,
        chiffre_choc=result.chiffre_choc,
        disclaimer=DISCLAIMER,
        sources=result.sources,
    )


# ---------------------------------------------------------------------------
# Retirement Budget
# ---------------------------------------------------------------------------

@router.post("/budget", response_model=RetirementBudgetResponse)
def budget_retirement(request: RetirementBudgetRequest) -> RetirementBudgetResponse:
    """Reconcile retirement income vs expenses.

    Aggregates AVS + LPP + 3a + other income, calculates replacement rate,
    checks indicative PC eligibility, and generates alerts.

    Sources: LAVS art. 29, LPP art. 14, OPC.
    """
    service = RetirementBudgetService()
    result = service.reconcile(
        avs_mensuel=request.avs_mensuel,
        lpp_mensuel=request.lpp_mensuel,
        capital_3a_net=request.capital_3a_net,
        autres_revenus=request.autres_revenus,
        depenses_mensuelles=request.depenses_mensuelles,
        revenu_pre_retraite=request.revenu_pre_retraite,
        is_couple=request.is_couple,
    )
    return RetirementBudgetResponse(
        revenus_mensuels=result.revenus_mensuels,
        total_revenus_mensuels=result.total_revenus_mensuels,
        depenses_mensuelles_estimees=result.depenses_mensuelles_estimees,
        solde_mensuel=result.solde_mensuel,
        taux_remplacement=result.taux_remplacement,
        pc_potentiellement_eligible=result.pc_potentiellement_eligible,
        duree_capital_3a_ans=result.duree_capital_3a_ans,
        alertes=result.alertes,
        chiffre_choc=result.chiffre_choc,
        checklist=result.checklist,
        disclaimer=result.disclaimer,
        sources=result.sources,
    )


# ---------------------------------------------------------------------------
# Checklist
# ---------------------------------------------------------------------------

@router.get("/checklist")
def retirement_checklist():
    """Return a comprehensive retirement preparation checklist.

    Stateless, no input needed. Returns actionable steps.
    """
    return {
        "checklist": [
            "Demander un extrait CI (compte individuel AVS) — gratuit",
            "Demander une estimation de rente LPP a ta caisse",
            "Consolider tous tes comptes 3a",
            "Etablir un budget retraite realiste",
            "Verifier l'eligibilite aux PC (prestations complementaires)",
            "Planifier le retrait echelonne du 3a",
            "Decider rente vs capital LPP (6 mois avant)",
            "Demander la rente AVS (3 mois avant)",
            "Mettre a jour les beneficiaires (LPP + 3a)",
            "Revoir les couvertures d'assurance (LAMal franchise, RC)",
        ],
        "disclaimer": DISCLAIMER,
    }
