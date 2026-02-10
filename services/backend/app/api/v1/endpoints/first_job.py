"""
First Job endpoints — Sprint S19: Chomage (LACI) + Premier emploi.

POST /api/v1/first-job/analyze    — Analyze first job salary
GET  /api/v1/first-job/checklist  — Get generic first job checklist

All endpoints are stateless (no data storage). Pure computation on the fly.
"""

from fastapi import APIRouter

from app.schemas.unemployment import (
    FirstJobRequest,
    FirstJobResponse,
    SalaryBreakdown,
    Pillar3aAdvice,
    LamalAdvice,
    FranchiseOption,
)
from app.services.first_job.onboarding_service import (
    FirstJobOnboardingService,
    get_first_job_checklist,
)


router = APIRouter()


# ---------------------------------------------------------------------------
# Analyze first job salary
# ---------------------------------------------------------------------------

@router.post("/analyze", response_model=FirstJobResponse)
def analyze_first_job(
    request: FirstJobRequest,
) -> FirstJobResponse:
    """Analyze a first job salary: deductions, 3a, LAMal, checklist.

    Provides a complete breakdown of gross-to-net salary, pillar 3a
    recommendations, LAMal franchise comparison, and onboarding checklist.

    Sources: LAVS art. 5, LACI art. 3, LPP art. 2/7/8/16, OPP3 art. 7, LAMal art. 61-65.
    """
    service = FirstJobOnboardingService()
    result = service.analyze_salary(
        salaire_brut_mensuel=request.salaire_brut_mensuel,
        canton=request.canton,
        age=request.age,
        etat_civil=request.etat_civil,
        has_children=request.has_children,
        taux_activite=request.taux_activite,
    )

    # Build nested models
    breakdown = SalaryBreakdown(**result["decomposition_salaire"])
    recommandations_3a = Pillar3aAdvice(**result["recommandations_3a"])
    lamal_data = result["recommandation_lamal"]
    franchise_options = [FranchiseOption(**opt) for opt in lamal_data["franchises_disponibles"]]
    recommandation_lamal = LamalAdvice(
        franchises_disponibles=franchise_options,
        franchise_recommandee=lamal_data["franchise_recommandee"],
        economie_annuelle_vs_300=lamal_data["economie_annuelle_vs_300"],
    )

    return FirstJobResponse(
        decomposition_salaire=breakdown,
        recommandations_3a=recommandations_3a,
        recommandation_lamal=recommandation_lamal,
        checklist_premier_emploi=result["checklist_premier_emploi"],
        alertes=result.get("alertes", []),
        chiffre_choc=result["chiffre_choc"],
        disclaimer=result["disclaimer"],
        sources=result["sources"],
    )


# ---------------------------------------------------------------------------
# Generic first job checklist
# ---------------------------------------------------------------------------

@router.get("/checklist")
def first_job_checklist():
    """Get the generic first job onboarding checklist.

    Useful for displaying information even before a specific salary analysis.
    """
    return get_first_job_checklist()
