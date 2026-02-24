"""
Scenario Narration + Annual Refresh endpoints — Sprint S37.

POST /api/v1/scenario/narrate       — Narrate 3 retirement scenarios
POST /api/v1/scenario/refresh-check — Check if profile needs annual refresh

Sources:
    - LSFin art. 3 (information financiere)
    - LPP art. 14-16 (prevoyance professionnelle)
    - LAVS art. 21-40 (AVS)
"""

from fastapi import APIRouter

from app.schemas.scenario_narration import (
    AnnualRefreshResponse,
    NarratedScenarioResponse,
    RefreshCheckRequest,
    RefreshQuestionResponse,
    ScenarioNarrationRequest,
    ScenarioNarrationResponse,
)
from app.services.scenario.annual_refresh_service import AnnualRefreshService
from app.services.scenario.scenario_models import ScenarioInput
from app.services.scenario.scenario_narrator_service import ScenarioNarratorService

router = APIRouter()

_narrator = ScenarioNarratorService()
_refresh = AnnualRefreshService()


@router.post("/narrate", response_model=ScenarioNarrationResponse)
def narrate_scenarios(
    request: ScenarioNarrationRequest,
) -> ScenarioNarrationResponse:
    """Narrer les scenarios de retraite en texte educatif.

    Transforme les projections numeriques (prudent/base/optimiste)
    en narratifs pedagogiques accessibles.

    Returns:
        ScenarioNarrationResponse avec narratifs, disclaimer, sources.
    """
    # Convert Pydantic schemas to dataclass inputs
    inputs = [
        ScenarioInput(
            label=sc.label,
            annual_return=sc.annual_return,
            capital_final=sc.capital_final,
            monthly_income=sc.monthly_income,
            replacement_ratio=sc.replacement_ratio,
        )
        for sc in request.scenarios
    ]

    result = _narrator.narrate_scenarios(
        scenarios=inputs,
        first_name=request.first_name,
        age=request.age,
    )

    return ScenarioNarrationResponse(
        scenarios=[
            NarratedScenarioResponse(
                label=ns.label,
                narrative=ns.narrative,
                annual_return_pct=ns.annual_return_pct,
                capital_final=ns.capital_final,
                monthly_income=ns.monthly_income,
            )
            for ns in result.scenarios
        ],
        disclaimer=result.disclaimer,
        sources=result.sources,
        uncertainty_mentioned=result.uncertainty_mentioned,
    )


@router.post("/refresh-check", response_model=AnnualRefreshResponse)
def check_annual_refresh(
    request: RefreshCheckRequest,
) -> AnnualRefreshResponse:
    """Verifier si le profil necessite une mise a jour annuelle.

    Detecte les profils obsoletes (> 11 mois sans mise a jour)
    et genere 7 questions de rafraichissement pre-remplies.

    Returns:
        AnnualRefreshResponse avec refresh_needed, questions, disclaimer.
    """
    result = _refresh.generate_refresh_questions(
        current_salary=request.current_salary,
        current_lpp=request.current_lpp,
        current_3a=request.current_3a,
        risk_profile=request.risk_profile,
        last_major_update=request.last_major_update,
    )

    return AnnualRefreshResponse(
        refresh_needed=result.refresh_needed,
        months_since_update=result.months_since_update,
        questions=[
            RefreshQuestionResponse(
                key=q.key,
                label=q.label,
                question_type=q.question_type,
                current_value=q.current_value,
                options=q.options,
            )
            for q in result.questions
        ],
        disclaimer=result.disclaimer,
        sources=result.sources,
    )
