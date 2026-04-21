"""
Coach services — Sprint S34 (Compliance Guard) + S56 (Coach Chat).

Provides:
    - ComplianceGuard: 5-layer validation pipeline for all LLM/coach output
    - HallucinationDetector: number verification against financial_core
    - PromptRegistry: versioned system prompts for LLM interactions
    - FallbackTemplates: deterministic, compliance-safe narrative templates
    - build_coach_context: pure function to build CoachContext from profile data
      (consumed by coach_chat.py:521 — NOT the removed S35 narrative cluster)

Wave E-PRIME (2026-04-18): CoachNarrativeService removed — Panel C audit
showed 0 Flutter caller for the 5 S35 endpoints (/coach/narrative,
/coach/greeting, /coach/score-summary, /coach/tip, /coach/premier-eclairage).
build_coach_context was initially scheduled for removal but coach_chat.py
also consumes it at line 521 via _build_coach_context_from_profile, so it
stays. Live path remains /coach/chat (conversational) + local fallback
templates in Flutter.

No LLM output reaches the user without passing through ComplianceGuard.
"""

from app.services.coach.coach_models import (
    ComplianceResult,
    CoachContext,
    CoachNarrativeResult,
    HallucinatedNumber,
    ComponentType,
)
from app.services.coach.compliance_guard import ComplianceGuard
from app.services.coach.hallucination_detector import HallucinationDetector
from app.services.coach.prompt_registry import PromptRegistry
from app.services.coach.fallback_templates import FallbackTemplates
from app.services.coach.coach_context_builder import build_coach_context
from app.services.coach.coach_tools import (
    COACH_TOOLS,
    ROUTE_TO_SCREEN_INTENT_TAGS,
    ToolCategory,
    get_tools_by_category,
    get_read_only_tools,
)
from app.services.coach.claude_coach_service import build_system_prompt
from app.services.coach.structured_reasoning import ReasoningOutput, StructuredReasoningService

__all__ = [
    "ComplianceResult",
    "CoachContext",
    "CoachNarrativeResult",
    "HallucinatedNumber",
    "ComponentType",
    "ComplianceGuard",
    "HallucinationDetector",
    "PromptRegistry",
    "FallbackTemplates",
    "build_coach_context",
    "COACH_TOOLS",
    "ROUTE_TO_SCREEN_INTENT_TAGS",
    "ToolCategory",
    "get_tools_by_category",
    "get_read_only_tools",
    "build_system_prompt",
    "ReasoningOutput",
    "StructuredReasoningService",
]
