"""
Coaching proactif endpoints.

POST /api/v1/coaching/tips — Generate personalized coaching tips

Sprint S11.
"""

from fastapi import APIRouter
from app.schemas.coaching import (
    CoachingProfileRequest,
    CoachingTipResponse,
    CoachingResponse,
)
from app.services.coaching_engine import CoachingEngine, CoachingProfile

router = APIRouter()

_engine = CoachingEngine()

DISCLAIMER = (
    "Ces suggestions sont indicatives et ne constituent pas un conseil "
    "financier personnalise. Consultez un·e spécialiste en finances pour une "
    "analyse adaptee a votre situation."
)


@router.post("/tips", response_model=CoachingResponse)
def generate_coaching_tips(
    request: CoachingProfileRequest,
) -> CoachingResponse:
    """Generate personalized coaching tips based on profile.

    Stateless endpoint — no data storage. All computation is done
    on the fly from the provided inputs.
    """
    profile = CoachingProfile(
        age=request.age,
        canton=request.canton,
        revenu_annuel=request.revenuAnnuel,
        has_3a=request.has3a,
        montant_3a=request.montant3a,
        has_lpp=request.hasLpp,
        avoir_lpp=request.avoirLpp,
        lacune_lpp=request.lacuneLpp,
        taux_activite=request.tauxActivite,
        charges_fixes_mensuelles=request.chargesFixesMensuelles,
        epargne_disponible=request.epargneDisponible,
        dette_totale=request.detteTotale,
        has_budget=request.hasBudget,
        employment_status=request.employmentStatus.value,
        etat_civil=request.etatCivil.value,
    )

    tips = _engine.generate_tips(profile)

    tip_responses = [
        CoachingTipResponse(
            id=tip.id,
            category=tip.category,
            priority=tip.priority,
            title=tip.title,
            message=tip.message,
            action=tip.action,
            estimatedImpactChf=tip.estimated_impact_chf,
            source=tip.source,
            icon=tip.icon,
        )
        for tip in tips
    ]

    return CoachingResponse(
        tips=tip_responses,
        disclaimer=DISCLAIMER,
    )
