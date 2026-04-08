"""
Coach Narrative endpoints — Sprint S35.

POST /api/v1/coach/narrative      — Generate all 4 narrative components
POST /api/v1/coach/greeting       — Generate greeting only
POST /api/v1/coach/score-summary  — Generate score summary only
POST /api/v1/coach/tip            — Generate tip narrative only
POST /api/v1/coach/premier-eclairage   — Generate premier éclairage reframe only

Sources:
    - LSFin art. 3 (information financiere)
    - LPD art. 6 (protection des donnees)
"""

from fastapi import APIRouter, Depends, Request

from app.core.auth import require_current_user
from app.core.rate_limit import limiter
from app.models.user import User

from app.schemas.coach import (
    CoachContextRequest,
    CoachNarrativeResponse,
    ComponentNarrativeResponse,
)
from app.services.coach.coach_context_builder import build_coach_context
from app.services.coach.coach_narrative_service import (
    CoachNarrativeService,
    STANDARD_DISCLAIMER,
    STANDARD_SOURCES,
)

router = APIRouter()

_service = CoachNarrativeService()


def _build_ctx(request: CoachContextRequest):
    """Convert Pydantic request to CoachContext."""
    return build_coach_context(
        first_name=request.first_name,
        age=request.age,
        canton=request.canton,
        archetype=request.archetype,
        fri_total=request.fri_total,
        fri_delta=request.fri_delta,
        primary_focus=request.primary_focus,
        replacement_ratio=request.replacement_ratio,
        months_liquidity=request.months_liquidity,
        tax_saving_potential=request.tax_saving_potential,
        confidence_score=request.confidence_score,
        days_since_last_visit=request.days_since_last_visit,
        fiscal_season=request.fiscal_season,
        upcoming_event=request.upcoming_event,
        check_in_streak=request.check_in_streak,
        last_milestone=request.last_milestone,
    )


@limiter.limit("30/minute")
@router.post("/narrative", response_model=CoachNarrativeResponse)
def generate_narrative(http_request: Request, request: CoachContextRequest, _user: User = Depends(require_current_user)) -> CoachNarrativeResponse:
    """Generer les 4 composants narratifs du coach.

    Chaque composant est genere independamment et valide
    par ComplianceGuard avant d'etre retourne.

    Returns:
        CoachNarrativeResponse avec greeting, score_summary,
        tip_narrative, premier_eclairage_reframe + metadata.
    """
    ctx = _build_ctx(request)
    result = _service.generate_all(ctx)

    return CoachNarrativeResponse(
        greeting=result.greeting,
        score_summary=result.score_summary,
        tip_narrative=result.tip_narrative,
        premier_eclairage_reframe=result.premier_eclairage_reframe,
        used_fallback=result.used_fallback,
        disclaimer=result.disclaimer,
        sources=result.sources,
    )


@limiter.limit("30/minute")
@router.post("/greeting", response_model=ComponentNarrativeResponse)
def generate_greeting(http_request: Request, request: CoachContextRequest, _user: User = Depends(require_current_user)) -> ComponentNarrativeResponse:
    """Generer uniquement le greeting personnalise.

    Returns:
        ComponentNarrativeResponse avec le greeting.
    """
    ctx = _build_ctx(request)
    text = _service.generate_greeting(ctx)

    return ComponentNarrativeResponse(
        component="greeting",
        text=text,
        used_fallback=True,
        disclaimer=STANDARD_DISCLAIMER,
        sources=list(STANDARD_SOURCES),
    )


@limiter.limit("30/minute")
@router.post("/score-summary", response_model=ComponentNarrativeResponse)
def generate_score_summary(http_request: Request, request: CoachContextRequest, _user: User = Depends(require_current_user)) -> ComponentNarrativeResponse:
    """Generer uniquement le resume du score FRI.

    Returns:
        ComponentNarrativeResponse avec le score summary.
    """
    ctx = _build_ctx(request)
    text = _service.generate_score_summary(ctx)

    return ComponentNarrativeResponse(
        component="score_summary",
        text=text,
        used_fallback=True,
        disclaimer=STANDARD_DISCLAIMER,
        sources=list(STANDARD_SOURCES),
    )


@limiter.limit("30/minute")
@router.post("/tip", response_model=ComponentNarrativeResponse)
def generate_tip(http_request: Request, request: CoachContextRequest, _user: User = Depends(require_current_user)) -> ComponentNarrativeResponse:
    """Generer uniquement le conseil educatif.

    Returns:
        ComponentNarrativeResponse avec le tip narrative.
    """
    ctx = _build_ctx(request)
    text = _service.generate_tip_narrative(ctx)

    return ComponentNarrativeResponse(
        component="tip_narrative",
        text=text,
        used_fallback=True,
        disclaimer=STANDARD_DISCLAIMER,
        sources=list(STANDARD_SOURCES),
    )


@limiter.limit("30/minute")
@router.post("/premier-eclairage", response_model=ComponentNarrativeResponse)
def generate_premier_eclairage(http_request: Request, request: CoachContextRequest, _user: User = Depends(require_current_user)) -> ComponentNarrativeResponse:
    """Generer uniquement la recontextualisation du premier éclairage.

    Returns:
        ComponentNarrativeResponse avec le premier éclairage reframe.
    """
    ctx = _build_ctx(request)
    text = _service.generate_premier_eclairage_reframe(ctx)

    return ComponentNarrativeResponse(
        component="premier_eclairage_reframe",
        text=text,
        used_fallback=True,
        disclaimer=STANDARD_DISCLAIMER,
        sources=list(STANDARD_SOURCES),
    )
