"""
Coaching proactif endpoints.

POST /api/v1/coaching/tips — Generate personalized coaching tips

Sprint S11.
"""

from fastapi import APIRouter, Request

from app.core.rate_limit import limiter
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
@limiter.limit("30/minute")
def generate_coaching_tips(
    request: Request,
    body: CoachingProfileRequest,
) -> CoachingResponse:
    """Generate personalized coaching tips based on profile.

    Stateless endpoint — no data storage. All computation is done
    on the fly from the provided inputs.
    """
    profile = CoachingProfile(
        age=body.age,
        canton=body.canton,
        revenu_annuel=body.revenuAnnuel,
        has_3a=body.has3a,
        montant_3a=body.montant3a,
        has_lpp=body.hasLpp,
        avoir_lpp=body.avoirLpp,
        lacune_lpp=body.lacuneLpp,
        taux_activite=body.tauxActivite,
        charges_fixes_mensuelles=body.chargesFixesMensuelles,
        epargne_disponible=body.epargneDisponible,
        dette_totale=body.detteTotale,
        has_budget=body.hasBudget,
        employment_status=body.employmentStatus.value,
        etat_civil=body.etatCivil.value,
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
