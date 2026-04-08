"""
FRI endpoints — Sprint S39: FRI Beta Display.

POST /api/v1/fri/current          — compute FRI + display rules
POST /api/v1/fri/simulate-action  — what-if simulation

All endpoints are stateless (no data storage). Pure computation on the fly.

Sources:
    - LAVS art. 21-29 (rente AVS)
    - LPP art. 14-16 (taux de conversion)
    - LIFD art. 38 (imposition du capital)
    - OPP3 art. 7 (plafond 3a)
    - FINMA circ. 2008/21 (gestion des risques)
"""

from fastapi import APIRouter, HTTPException, Request

from app.core.rate_limit import limiter
from app.schemas.fri import (
    FriBreakdownResponse,
    FriComputeRequest,
    FriDisplayResponse,
    FriSimulateRequest,
    FriSimulateResponse,
)
from app.services.fri.fri_service import FriInput
from app.services.fri.fri_display_service import FriDisplayService

router = APIRouter()


def _input_schema_to_dataclass(schema) -> FriInput:
    """Convert FriInputSchema Pydantic model to FriInput dataclass."""
    return FriInput(
        liquid_assets=schema.liquid_assets,
        monthly_fixed_costs=schema.monthly_fixed_costs,
        short_term_debt_ratio=schema.short_term_debt_ratio,
        income_volatility=schema.income_volatility,
        actual_3a=schema.actual_3a,
        max_3a=schema.max_3a,
        potentiel_rachat_lpp=schema.potentiel_rachat_lpp,
        rachat_effectue=schema.rachat_effectue,
        taux_marginal=schema.taux_marginal,
        is_property_owner=schema.is_property_owner,
        amort_indirect=schema.amort_indirect,
        replacement_ratio=schema.replacement_ratio,
        disability_gap_ratio=schema.disability_gap_ratio,
        has_dependents=schema.has_dependents,
        death_protection_gap_ratio=schema.death_protection_gap_ratio,
        mortgage_stress_ratio=schema.mortgage_stress_ratio,
        concentration_ratio=schema.concentration_ratio,
        employer_dependency_ratio=schema.employer_dependency_ratio,
        archetype=schema.archetype,
        age=schema.age,
        canton=schema.canton,
    )


def _breakdown_to_response(b) -> FriBreakdownResponse:
    """Convert FriBreakdown dataclass to Pydantic response."""
    return FriBreakdownResponse(
        liquidite=b.liquidite,
        fiscalite=b.fiscalite,
        retraite=b.retraite,
        risque=b.risque,
        total=b.total,
        model_version=b.model_version,
        confidence_score=b.confidence_score,
    )


@router.post(
    "/current",
    response_model=FriDisplayResponse,
    summary="Calculer le FRI avec regles d'affichage",
    description=(
        "Calcule le Financial Resilience Index et applique les regles "
        "d'affichage (seuil de confiance, action prioritaire, disclaimer). "
        "Outil educatif — ne constitue pas un conseil financier (LSFin)."
    ),
)
@limiter.limit("10/minute")
async def compute_fri_current(request: Request, body: FriComputeRequest) -> FriDisplayResponse:
    """Compute FRI with display rules.

    Returns FriDisplayResponse with breakdown, display permission,
    top improvement action, and compliance fields.
    """
    inp = _input_schema_to_dataclass(body.input_data)

    result = FriDisplayService.compute_for_display(inp, body.confidence_score)

    return FriDisplayResponse(
        breakdown=_breakdown_to_response(result.breakdown),
        display_allowed=result.display_allowed,
        top_action=result.top_action,
        top_action_delta=result.top_action_delta,
        enrichment_message=result.enrichment_message,
        disclaimer=result.disclaimer,
        sources=result.sources,
    )


@router.post(
    "/simulate-action",
    response_model=FriSimulateResponse,
    summary="Simuler une action d'amelioration FRI",
    description=(
        "Simule l'impact d'une action specifique sur le score FRI. "
        "Actions: add_3a, add_liquidity, add_rachat, reduce_mortgage. "
        "Outil educatif — ne constitue pas un conseil financier (LSFin)."
    ),
)
@limiter.limit("10/minute")
async def simulate_fri_action(request: Request, body: FriSimulateRequest) -> FriSimulateResponse:
    """Simulate a specific action and return the FRI delta.

    Returns FriSimulateResponse with delta, new breakdown, and description.
    """
    inp = _input_schema_to_dataclass(body.input_data)

    try:
        result = FriDisplayService.simulate_action(
            inp, body.action_type, body.confidence_score,
        )
    except ValueError:
        raise HTTPException(status_code=422, detail="Unprocessable input")

    return FriSimulateResponse(
        delta_fri=result["delta_fri"],
        new_breakdown=_breakdown_to_response(result["new_breakdown"]),
        action_description=result["action_description"],
        disclaimer=result["disclaimer"],
        sources=result["sources"],
    )
