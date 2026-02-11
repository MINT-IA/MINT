"""
Disability Gap endpoints — simulation du gap financier en cas d'invalidite.

POST /api/v1/disability-gap/compute — calcule le gap sur 3 phases

Calcule le deficit financier si l'utilisateur ne peut plus travailler:
- Phase 1: Couverture employeur (CO art. 324a)
- Phase 2: IJM (indemnites journalieres maladie)
- Phase 3: AI (assurance invalidite) + rente LPP invalidite

All endpoints are stateless (no data storage). Pure computation on the fly.
"""

from fastapi import APIRouter, HTTPException

from app.schemas.disability_gap import (
    DisabilityGapRequest,
    DisabilityGapResponse,
)
from app.services.disability_gap_service import (
    compute_disability_gap,
    EmploymentStatus,
)

router = APIRouter()


@router.post("/compute", response_model=DisabilityGapResponse)
def compute(request: DisabilityGapRequest) -> DisabilityGapResponse:
    """Calcule le gap financier en cas d'invalidite sur 3 phases.

    Phase 1 : couverture employeur (CO art. 324a), duree selon echelle cantonale.
    Phase 2 : IJM a 80% du salaire, max 24 mois.
    Phase 3 : AI + LPP invalidite (long terme).

    Returns:
        DisabilityGapResponse avec le detail des 3 phases, risque, alertes,
        chiffre choc, disclaimer et sources legales.
    """
    try:
        # Map schema enum to service enum
        status_map = {
            "employee": EmploymentStatus.EMPLOYEE,
            "self_employed": EmploymentStatus.SELF_EMPLOYED,
            "mixed": EmploymentStatus.MIXED,
            "unemployed": EmploymentStatus.UNEMPLOYED,
            "student": EmploymentStatus.STUDENT,
        }
        statut = status_map[request.statut_professionnel.value]

        result = compute_disability_gap(
            revenu_mensuel_net=request.revenu_mensuel_net,
            statut_professionnel=statut,
            canton=request.canton.upper(),
            annees_anciennete=request.annees_anciennete,
            has_ijm_collective=request.has_ijm_collective,
            degre_invalidite=request.degre_invalidite,
            lpp_disability_benefit=request.lpp_disability_benefit,
        )

        return DisabilityGapResponse(
            revenu_actuel=result.revenu_actuel,
            phase1_duration_weeks=result.phase1_duration_weeks,
            phase1_monthly_benefit=result.phase1_monthly_benefit,
            phase1_gap=result.phase1_gap,
            phase2_duration_months=result.phase2_duration_months,
            phase2_monthly_benefit=result.phase2_monthly_benefit,
            phase2_gap=result.phase2_gap,
            phase3_monthly_benefit=result.phase3_monthly_benefit,
            phase3_gap=result.phase3_gap,
            risk_level=result.risk_level,
            alerts=result.alerts,
            ai_rente_mensuelle=result.ai_rente_mensuelle,
            lpp_disability_benefit=result.lpp_disability_benefit,
            chiffre_choc=result.chiffre_choc,
            disclaimer=result.disclaimer,
            sources=result.sources,
        )

    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
