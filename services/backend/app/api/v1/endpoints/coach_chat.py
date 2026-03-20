"""
Coach Chat endpoint — S56.

POST /api/v1/coach/chat — Conversational AI with Claude proxy.

The API key stays server-side (Railway secret ANTHROPIC_API_KEY).
Rate limiting per user. ComplianceGuard on all output.

Sources:
    - LSFin art. 3 (information financiere educative)
    - LPD art. 6 (protection des donnees)
"""

import logging
from datetime import date

from fastapi import APIRouter, HTTPException

from app.schemas.coach_chat import (
    CoachChatRequest,
    CoachChatResponse,
    WidgetCall,
)
from app.services.coach.claude_coach_service import (
    ClaudeCoachService,
    build_system_prompt,
    DISCLAIMER,
)

logger = logging.getLogger(__name__)

router = APIRouter()

_service: ClaudeCoachService | None = None


def _get_service() -> ClaudeCoachService:
    """Lazy init — ensures env vars are loaded before reading API key."""
    global _service
    if _service is None:
        _service = ClaudeCoachService()
    return _service

# Simple in-memory quota tracking (per-user per-day).
# In production, replace with Redis or DB.
_daily_usage: dict[str, dict] = {}  # {user_id: {date: str, count: int}}


def _check_quota(user_id: str, daily_limit: int = 30) -> int:
    """Check and increment user quota. Returns remaining count."""
    today = date.today().isoformat()

    if user_id not in _daily_usage:
        _daily_usage[user_id] = {"date": today, "count": 0}

    entry = _daily_usage[user_id]
    if entry["date"] != today:
        entry["date"] = today
        entry["count"] = 0

    if entry["count"] >= daily_limit:
        return 0

    entry["count"] += 1
    return daily_limit - entry["count"]


@router.post("/chat", response_model=CoachChatResponse)
def coach_chat(request: CoachChatRequest) -> CoachChatResponse:
    """Conversational coach powered by Claude.

    The system prompt includes MINT voice (5 pillars), user context,
    financial literacy adaptation, and CapMemory for coach continuity.

    Rate limited to COACH_DAILY_QUOTA messages per user per day.
    All output filtered by ComplianceGuard.
    """
    service = _get_service()
    if not service.is_available:
        return CoachChatResponse(
            reply=(
                "Le coach IA n'est pas disponible pour le moment. "
                "Les outils et simulateurs restent accessibles."
            ),
            used_model="unavailable",
            tokens_used=0,
        )

    # Quota check (use first_name + age as pseudo user_id for beta)
    user_id = f"{request.first_name or 'anon'}_{request.age or 0}"
    from app.core.config import settings
    remaining = _check_quota(user_id, settings.COACH_DAILY_QUOTA)

    if remaining <= 0:
        return CoachChatResponse(
            reply=(
                "Tu as atteint la limite du jour. "
                "Reviens demain, ou explore les outils directement."
            ),
            used_model="quota_exceeded",
            tokens_used=0,
            remaining_quota=0,
        )

    # Build system prompt with full context
    system_prompt = build_system_prompt(
        first_name=request.first_name,
        age=request.age,
        canton=request.canton,
        salary_annual=request.salary_annual,
        civil_status=request.civil_status,
        archetype=request.archetype,
        financial_literacy_level=request.financial_literacy_level or "intermediate",
        fri_total=request.fri_total,
        replacement_ratio=request.replacement_ratio,
        confidence_score=request.confidence_score,
        avoir_lpp=request.avoir_lpp,
        epargne_3a=request.epargne_3a,
        total_dettes=request.total_dettes,
        last_cap_served=request.last_cap_served,
        completed_actions=request.completed_actions,
        abandoned_flows=request.abandoned_flows,
        declared_goals=request.declared_goals,
    )

    # Call Claude
    history = [
        {"role": m.role, "content": m.content}
        for m in request.conversation_history[-20:]
    ]

    result = service.chat(
        message=request.message,
        conversation_history=history,
        system_prompt=system_prompt,
    )

    # Build response with optional widget from Claude tool call
    widget_data = result.get("widget")
    widget = WidgetCall(
        tool=widget_data["tool"],
        params=widget_data["params"],
    ) if widget_data else None

    return CoachChatResponse(
        reply=result["reply"],
        widget=widget,
        disclaimer=DISCLAIMER,
        used_model=result["model"],
        tokens_used=result["tokens_used"],
        remaining_quota=remaining,
    )
