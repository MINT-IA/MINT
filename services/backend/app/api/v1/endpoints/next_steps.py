"""
Next Steps endpoints — recommandations de simulateurs et evenements de vie.

POST /api/v1/next-steps/calculate — genere les prochaines etapes personnalisees

Recommends relevant simulators and life events based on user profile,
prioritized by urgency and relevance. Pure educational recommendations,
never prescriptive.

All endpoints are stateless (no data storage). Pure computation on the fly.
"""

from fastapi import APIRouter

from app.schemas.next_steps import (
    NextStepsRequest,
    NextStepItem,
    NextStepsResponse,
)
from app.services.next_steps_service import (
    NextStepsService,
    NextStepsInput,
)

router = APIRouter()

# Service instance (stateless, safe to reuse)
_service = NextStepsService()


@router.post("/calculate", response_model=NextStepsResponse)
def calculate(request: NextStepsRequest) -> NextStepsResponse:
    """Genere des recommendations de prochaines etapes personnalisees.

    Analyse le profil utilisateur et retourne jusqu'a 5 etapes
    prioritisees, chacune liee a un evenement de vie et un simulateur.

    Returns:
        NextStepsResponse avec la liste des etapes, disclaimer et sources.
    """
    input_data = NextStepsInput(
        age=request.age,
        civil_status=request.civil_status,
        children_count=request.children_count,
        employment_status=request.employment_status,
        monthly_net_income=request.monthly_net_income,
        canton=request.canton,
        has_3a=request.has_3a,
        has_pension_fund=request.has_pension_fund,
        has_debt=request.has_debt,
        has_real_estate=request.has_real_estate,
        has_investments=request.has_investments,
    )

    result = _service.calculate(input_data)

    steps = [
        NextStepItem(
            life_event=step.life_event,
            title=step.title,
            reason=step.reason,
            priority=step.priority,
            route=step.route,
            icon_name=step.icon_name,
        )
        for step in result.steps
    ]

    return NextStepsResponse(
        steps=steps,
        disclaimer=result.disclaimer,
        sources=result.sources,
    )
