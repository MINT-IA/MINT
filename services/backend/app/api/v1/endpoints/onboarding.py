"""
Onboarding endpoints — Sprint S31: Onboarding Redesign.

POST /api/v1/onboarding/minimal-profile — compute minimal financial profile
POST /api/v1/onboarding/chiffre-choc   — select impactful chiffre choc

Given only 3 inputs (age, salary, canton), produces:
- A full financial snapshot with confidence scoring
- A single impactful "chiffre choc" to motivate the user

All endpoints are stateless (no data storage). Pure computation on the fly.

Sources:
    - LAVS art. 21-29 (rente AVS)
    - LPP art. 15-16 (bonifications vieillesse)
    - LIFD art. 38 (imposition du capital)
    - OPP3 art. 7 (plafond 3a)
"""

from fastapi import APIRouter, HTTPException, Request

from app.core.rate_limit import limiter
from app.schemas.onboarding import (
    MinimalProfileRequest,
    MinimalProfileResponse,
    ChiffreChocResponse,
)
from app.services.onboarding import (
    MinimalProfileInput,
    compute_minimal_profile,
    select_chiffre_choc,
)

router = APIRouter()


def _request_to_input(request: MinimalProfileRequest) -> MinimalProfileInput:
    """Convert Pydantic request to service dataclass input."""
    return MinimalProfileInput(
        age=request.age,
        gross_salary=request.gross_salary,
        canton=request.canton.upper(),
        household_type=request.household_type,
        current_savings=request.current_savings,
        is_property_owner=request.is_property_owner,
        existing_3a=request.existing_3a,
        existing_lpp=request.existing_lpp,
        lpp_caisse_type=request.lpp_caisse_type,
        total_debts=request.total_debts,
        monthly_debt_service=request.monthly_debt_service,
    )


@router.post("/minimal-profile", response_model=MinimalProfileResponse)
@limiter.limit("30/minute")
def compute_profile(request: Request, body: MinimalProfileRequest) -> MinimalProfileResponse:
    """Calcule un profil financier minimal a partir de 3 inputs.

    Seuls age, salaire brut et canton sont requis. Les champs optionnels
    (situation familiale, epargne, 3a, LPP) enrichissent la projection
    et augmentent le score de confiance.

    Returns:
        MinimalProfileResponse avec projections, confiance, disclaimer et sources.
    """
    try:
        input_data = _request_to_input(body)
        result = compute_minimal_profile(input_data)

        return MinimalProfileResponse(
            projected_avs_monthly=result.projected_avs_monthly,
            projected_lpp_capital=result.projected_lpp_capital,
            projected_lpp_monthly=result.projected_lpp_monthly,
            estimated_replacement_ratio=result.estimated_replacement_ratio,
            estimated_monthly_retirement=result.estimated_monthly_retirement,
            estimated_monthly_expenses=result.estimated_monthly_expenses,
            retirement_gap_monthly=result.retirement_gap_monthly,
            monthly_debt_impact=result.monthly_debt_impact,
            tax_saving_3a=result.tax_saving_3a,
            marginal_tax_rate=result.marginal_tax_rate,
            months_liquidity=result.months_liquidity,
            confidence_score=result.confidence_score,
            estimated_fields=result.estimated_fields,
            archetype=result.archetype,
            disclaimer=result.disclaimer,
            sources=result.sources,
            enrichment_prompts=result.enrichment_prompts,
        )

    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid request parameters")


@router.post("/chiffre-choc", response_model=ChiffreChocResponse)
@limiter.limit("30/minute")
def compute_chiffre_choc(request: Request, body: MinimalProfileRequest) -> ChiffreChocResponse:
    """Calcule le chiffre choc le plus percutant pour l'onboarding.

    Prend les memes inputs que le profil minimal, calcule le profil
    en interne, puis selectionne LE chiffre choc le plus impactant.

    Priorite:
    1. Crise de liquidite (< 2 mois de reserve)
    2. Gap retraite (taux de remplacement < 55%)
    3. Economie fiscale 3a (pas de 3a + economie > 1'500 CHF)
    4. Fallback: gap retraite

    Returns:
        ChiffreChocResponse avec categorie, texte d'accroche, disclaimer et sources.
    """
    try:
        input_data = _request_to_input(body)
        profile = compute_minimal_profile(input_data)
        choc = select_chiffre_choc(profile)

        return ChiffreChocResponse(
            category=choc.category,
            primary_number=choc.primary_number,
            display_text=choc.display_text,
            explanation_text=choc.explanation_text,
            action_text=choc.action_text,
            disclaimer=choc.disclaimer,
            sources=choc.sources,
            confidence_score=choc.confidence_score,
        )

    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid request parameters")
