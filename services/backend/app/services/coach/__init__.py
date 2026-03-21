"""
Coach services — Sprint S34 (Compliance Guard) + S35 (Coach Narrative Service).

Provides:
    - ComplianceGuard: 5-layer validation pipeline for all LLM/coach output
    - HallucinationDetector: number verification against financial_core
    - PromptRegistry: versioned system prompts for LLM interactions
    - FallbackTemplates: deterministic, compliance-safe narrative templates
    - CoachNarrativeService: 4-component narrative generator with guard integration
    - build_coach_context: pure function to build CoachContext from profile data

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
from app.services.coach.coach_narrative_service import CoachNarrativeService
from app.services.coach.coach_tools import COACH_TOOLS, ROUTE_TO_SCREEN_INTENT_TAGS
from app.services.coach.claude_coach_service import build_system_prompt

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
    "CoachNarrativeService",
    "COACH_TOOLS",
    "ROUTE_TO_SCREEN_INTENT_TAGS",
    "build_system_prompt",
]
